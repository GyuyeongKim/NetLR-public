#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif
#define OP_READ 0
#define OP_R_REPLY 1
#define OP_WRITE 2
#define OP_W_REPLY 3
#define MAX_NUM_REPLICA 8
#define NUM_OBJ 131072
/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

typedef bit<16> ether_type_t;
const ether_type_t TYPE_IPV4 = 0x800;
typedef bit<8> trans_protocol_t;
const trans_protocol_t TYPE_TCP = 6;
const trans_protocol_t TYPE_UDP = 17;
const bit<16> TYPE_NETLR = 1234; // NOT 0x1234

header ethernet_h {
    bit<48>   dstAddr;
    bit<48>   srcAddr;
    bit<16>   etherType;
}

header netlr_h {
    bit<8> op;
    bit<32> id;
    bit<32> seq;
    bit<32> oid;
}

header ipv4_h {
    bit<4>   version;
    bit<4>   ihl;
    bit<6>   dscp;
    bit<2>   ecn;
    bit<16>  totalLen;
    bit<16>  identification;
    bit<3>   flags;
    bit<13>  frag_offset;
    bit<8>   ttl;
    bit<8>   protocol;
    bit<16>  hdrChecksum;
    bit<32>  srcAddr;
    bit<32>  dstAddr;
}

header tcp_h {
    bit<16> srcport;
    bit<16> dstport;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4> dataOffset;
    bit<3>  res;
    bit<3>  ecn;
    bit<6>  ctrl;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgent_ptr;
}

header udp_h {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> len;
    bit<16> checksum;
}
struct header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    tcp_h tcp;
    udp_h udp;
    netlr_h netlr;
}

struct metadata_t {
    bit<8> num_replica;
    bit<8> dst_rep_id;
    bit<8> num_valid_replica;
    bit<2> dset_success;
    bit<2> commit;
    bit<1> CurWriteSeq;
    bit<8> cur_rep_id;
}

struct custom_metadata_t {

}

struct empty_header_t {
    ethernet_h ethernet;
    ipv4_h ipv4;
    tcp_h tcp;
    udp_h udp;
    netlr_h netlr;
}

struct empty_metadata_t {
    custom_metadata_t custom_metadata;
}

Register<bit<32>,_>(NUM_OBJ,0) dset;
Register<bit<32>,_>(NUM_OBJ,0) lseq;
Register<bit<8>,_>(NUM_OBJ,0) num_valid_replica;
Register<bit<8>,_>(NUM_OBJ,0) latest_known_valid_replica_id;
Register<bit<8>,_>(1,0) DstRepIdx;
Register<bit<8>,_>(1,0) num_replica;
Register<bit<32>,_>(1,0) seq;

/*************************************************************************
*********************** P A R S E R  ***********************************
*************************************************************************/

parser SwitchIngressParser(
        packet_in pkt,
        out header_t hdr,
        out metadata_t ig_md,
        out ingress_intrinsic_metadata_t ig_intr_md) {

    state start {
        pkt.extract(ig_intr_md);
        pkt.advance(PORT_METADATA_SIZE);
        transition parse_ethernet;
    }

    state parse_ethernet {
        pkt.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            TYPE_IPV4: parse_ipv4;
            default: accept;
        }
    }

    state parse_ipv4 {
        pkt.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            TYPE_UDP: parse_udp;
            default: accept;
        }
    }

    state parse_udp {
        pkt.extract(hdr.udp);
        #transition parse_netlr;
        transition select(hdr.udp.dstPort){
            TYPE_NETLR: parse_netlr;
            default: accept;
        }
    }

    state parse_netlr {
        pkt.extract(hdr.netlr);
        transition accept;
    }

}

/*************************************************************************
**************  I N G R E S S   P R O C E S S I N G   *******************
*************************************************************************/

control SwitchIngress(
        inout header_t hdr,
        inout metadata_t ig_md,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_intr_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {



    RegisterAction<bit<32>, _, bit<32>>(lseq) update_lseq = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            reg_value = hdr.netlr.seq;
        }
    };
    action update_lseq_action(){
        update_lseq.execute(hdr.netlr.id);
    }

    table update_lseq_table{
        actions = {
            update_lseq_action;
        }
        size = 1;
        default_action = update_lseq_action;
    }


    action drop() {
        ig_intr_dprsr_md.drop_ctl=1;
    }

    action ipv4_forward(bit<9> port) {
        ig_tm_md.ucast_egress_port = port;
    }

    table ipv4_exact {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 16;
       default_action = drop();
    }

    table netlr_l3_forward {
        key = {
            hdr.ipv4.dstAddr: exact;
        }
        actions = {
            ipv4_forward;
            drop;
            NoAction;
        }
        size = 16;
       default_action = drop();
    }

    action msg_cloning_action(){
        ig_tm_md.rid = 1;
        ig_tm_md.mcast_grp_a = 1;
    }

    table msg_cloning_table{
        actions = {
            msg_cloning_action;
        }
        size = 1;
        default_action = msg_cloning_action;
    }


    RegisterAction<bit<32>, _, bit<32>>(dset) get_dset = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            if (reg_value == hdr.netlr.oid)
                return_value = 1;

        }
    };

    action get_dset_action(){
        ig_md.dset_success = (bit<2>)get_dset.execute(hdr.netlr.id);
    }

    @pragma stage 2
    table get_dset_table{
        actions = {
            get_dset_action;
        }
        size = 1;
        default_action = get_dset_action;
    }

    RegisterAction<bit<32>, _, bit<32>>(seq) inc_seq = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            reg_value = reg_value + 1;
            return_value = reg_value;
        }
    };

    action inc_seq_action(){
        hdr.netlr.seq = inc_seq.execute(0);
    }

    table inc_seq_table{
        actions = {
            inc_seq_action;
        }
        size = 1;
        default_action = inc_seq_action;
    }

    RegisterAction<bit<8>, _, bit<8>>(num_replica) get_num_replica = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            return_value = reg_value;
        }
    };

    action get_num_replica_action(){
        ig_md.num_replica = get_num_replica.execute(0);
    }


    table get_num_replica_table{
        actions = {
            get_num_replica_action;
        }
        size = 1;
        default_action = get_num_replica_action;
    }


    RegisterAction<bit<8>, _, bit<8>>(num_valid_replica) get_valid_replica = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            return_value = reg_value;
        }
    };

    action get_valid_replica_action(){
        ig_md.num_valid_replica = get_valid_replica.execute(hdr.netlr.id);
    }

    table get_valid_replica_table{
        actions = {
            get_valid_replica_action;
        }
        size = 1;
        default_action = get_valid_replica_action;
    }

    RegisterAction<bit<8>, _, bit<8>>(latest_known_valid_replica_id) update_valid_replica_id = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            reg_value = ig_md.cur_rep_id;
        }
    };

    action update_valid_replica_id_action(){
        update_valid_replica_id.execute(hdr.netlr.id);
    }


    table update_valid_replica_id_table{
        actions = {
            update_valid_replica_id_action;
        }
        size = 1;
        default_action = update_valid_replica_id_action;
    }


    RegisterAction<bit<32>, _, bit<32>>(dset) put_dset = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            if (reg_value == 0 || reg_value == hdr.netlr.oid){
                reg_value = hdr.netlr.oid;
                return_value = 1;
            }
        }
    };

    action put_dset_action(){
        ig_md.dset_success = (bit<2>)put_dset.execute(hdr.netlr.id);
    }

    @pragma stage 2
    table put_dset_table{
        actions = {
            put_dset_action;
        }
        size = 1;
        default_action = put_dset_action;
    }



    RegisterAction<bit<8>, _, bit<8>>(num_valid_replica) inc_valid_replica_size = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            if(reg_value == ig_md.num_replica - 1){
                reg_value = 0;
                return_value = 1;
            }
            else{
                reg_value = reg_value + 1;
                return_value = 0;
            }
        }
    };

    action inc_valid_replica_size_action(){
         ig_md.commit = (bit<2>)inc_valid_replica_size.execute(hdr.netlr.id);
    }

    table inc_valid_replica_size_table{
        actions = {
            inc_valid_replica_size_action;
        }
        size = 1;
        default_action = inc_valid_replica_size_action;
    }



    action get_cur_rep_id_action(bit<8> rep_id){
        ig_md.cur_rep_id = rep_id;
    }

    table get_cur_rep_id_table{
        key = {
            hdr.ipv4.srcAddr: exact;
        }
        actions = {
            get_cur_rep_id_action;
            NoAction;
        }
        size = MAX_NUM_REPLICA;
        default_action = NoAction();
    }

    RegisterAction<bit<8>, _, bit<8>>(DstRepIdx) get_dst_rep_rr_all = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            return_value = reg_value;
            if(reg_value >= ig_md.num_replica - 1)
                reg_value = 0;
            else
                reg_value = reg_value + 1;

        }
    };

    action get_dst_rep_rr_all_action(){
        ig_md.dst_rep_id = get_dst_rep_rr_all.execute(0);
    }

    table get_dst_rep_rr_all_table{
        actions = {
            get_dst_rep_rr_all_action;
        }
        size = 1;
        default_action = get_dst_rep_rr_all_action;
    }

    RegisterAction<bit<8>, _, bit<8>>(latest_known_valid_replica_id) get_dst_rep_id_using_RepIdx = {
        void apply(inout bit<8> reg_value, out bit<8> return_value) {
            return_value = reg_value;
        }
    };

    action get_dst_rep_id_using_RepIdx_action(){
        ig_md.dst_rep_id = get_dst_rep_id_using_RepIdx.execute(hdr.netlr.id);
    }

    table get_dst_rep_id_using_RepIdx_table{
        actions = {
            get_dst_rep_id_using_RepIdx_action;
        }
        size = 1;
        default_action = get_dst_rep_id_using_RepIdx_action;
    }

    action get_dst_rep_ip_action(bit<32> addr,bit<9> port){
        hdr.ipv4.dstAddr = addr;
        ig_tm_md.ucast_egress_port = port;
    }

    table get_dst_rep_ip_table{
        key = {
            ig_md.dst_rep_id: exact;
        }
        actions = {
            get_dst_rep_ip_action;
        }
        size = MAX_NUM_REPLICA;
        default_action = get_dst_rep_ip_action(0,0x0);
    }


    RegisterAction<bit<32>, _, bit<32>>(dset) del_dset = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            if (ig_md.commit == 1)
                reg_value = 0;
        }
    };

    action del_dset_action(){
        del_dset.execute(hdr.netlr.id);
    }

    table del_dset_table{
        actions = {
            del_dset_action;
        }
        size = 1;
        default_action = del_dset_action;
    }


    RegisterAction<bit<32>, _, bit<32>>(lseq) compare_lseq = {
        void apply(inout bit<32> reg_value, out bit<32> return_value) {
            if (hdr.netlr.seq >= reg_value){
                reg_value = hdr.netlr.seq;
                return_value = 1;
            }

        }
    };
    action compare_lseq_action(){
        ig_md.CurWriteSeq = (bit<1>) compare_lseq.execute(hdr.netlr.id);
    }

    table compare_lseq_table{
        actions = {
            compare_lseq_action;
        }
        size = 1;
        default_action = compare_lseq_action;
    }

    apply {
        /*************** NetLR Block START *****************************/
            if (hdr.netlr.isValid()){
                hdr.udp.checksum = 0; // Disable UDP checksum. 
                get_num_replica_table.apply();
                if (hdr.netlr.op == OP_READ || hdr.netlr.op == OP_WRITE){
                    if (hdr.netlr.op == OP_READ){
                        get_dset_table.apply();
                        if (ig_md.dset_success == 1)
                            get_dst_rep_id_using_RepIdx_table.apply();
                        else
                            get_dst_rep_rr_all_table.apply();
                        get_dst_rep_ip_table.apply();
                    }
                    else if (hdr.netlr.op == OP_WRITE){
                        put_dset_table.apply();
                        if (ig_md.dset_success == 1){
                            inc_seq_table.apply();
                            msg_cloning_table.apply();
                        }
                    }
                }
                else if (hdr.netlr.op == OP_R_REPLY || hdr.netlr.op == OP_W_REPLY){
                    if (hdr.netlr.op == OP_W_REPLY){
                        compare_lseq_table.apply();
                        if (ig_md.CurWriteSeq == 1){
                            inc_valid_replica_size_table.apply();
                            del_dset_table.apply();
                            get_cur_rep_id_table.apply();
                            update_valid_replica_id_table.apply();
                            if (ig_md.commit == 0)
                                drop();
                        }
                    }
                    netlr_l3_forward.apply();
                }
            }
            else
                ipv4_exact.apply();
            /*************** NetLR Block END *****************************/
    }
}



/*************************************************************************
***********************  D E P A R S E R  *******************************
*************************************************************************/
control SwitchIngressDeparser(
        packet_out pkt,
        inout header_t hdr,
        in metadata_t ig_md,
        in ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md) {
    Checksum() ipv4_checksum;

    apply {

        hdr.ipv4.hdrChecksum = ipv4_checksum.update(
                        {hdr.ipv4.version,
                         hdr.ipv4.ihl,
                         hdr.ipv4.dscp,
                         hdr.ipv4.ecn,
                         hdr.ipv4.totalLen,
                         hdr.ipv4.identification,
                         hdr.ipv4.flags,
                         hdr.ipv4.frag_offset,
                         hdr.ipv4.ttl,
                         hdr.ipv4.protocol,
                         hdr.ipv4.srcAddr,
                         hdr.ipv4.dstAddr});


        pkt.emit(hdr);
    }
}


/*************************************************************************
****************  E G R E S S   P R O C E S S I N G   *******************
*************************************************************************/
parser SwitchEgressParser(
        packet_in pkt,
        out empty_header_t hdr,
        out empty_metadata_t eg_md,
        out egress_intrinsic_metadata_t eg_intr_md) {
    state start {
        pkt.extract(eg_intr_md);
        transition accept;
    }
}

control SwitchEgressDeparser(
        packet_out pkt,
        inout empty_header_t hdr,
        in empty_metadata_t eg_md,
        in egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md) {
    apply {
        pkt.emit(hdr);
    }
}

control SwitchEgress(
        inout empty_header_t hdr,
        inout empty_metadata_t eg_md,
        in egress_intrinsic_metadata_t eg_intr_md,
        in egress_intrinsic_metadata_from_parser_t eg_intr_md_from_prsr,
        inout egress_intrinsic_metadata_for_deparser_t ig_intr_dprs_md,
        inout egress_intrinsic_metadata_for_output_port_t eg_intr_oport_md) {

    apply {

    }
}
/*************************************************************************
***********************  S W I T C H  *******************************
*************************************************************************/
Pipeline(SwitchIngressParser(),
         SwitchIngress(),
         SwitchIngressDeparser(),
         SwitchEgressParser(),
         SwitchEgress(),
         SwitchEgressDeparser()) pipe;

Switch(pipe) main;
