import sys
import os
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/tofino/'))
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/tofino/bfrt_grpc'))
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/'))
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/tofinopd/'))
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/tofino_pd_api/'))
sys.path.append(os.path.expandvars('$SDE/install/lib/python3.8/site-packages/p4testutils'))
import grpc
import time
import datetime
import bfrt_grpc.client as gc
import port_mgr_pd_rpc as mr
from time import sleep
import socket, struct
import binascii


def hex2ip(hex_ip):
	addr_long = int(hex_ip,16)
	hex(addr_long)
	hex_ip = socket.inet_ntoa(struct.pack(">L", addr_long))
	return hex_ip

# Convert IP to bin
def ip2bin(ip):
	ip1 = ''.join([bin(int(x)+256)[3:] for x in ip.split('.')])
	return ip1

# Convert IP to hex
def ip2hex(ip):
	ip1 = ''.join([hex(int(x)+256)[3:] for x in ip.split('.')])
	return ip1

def table_add(target, table, keys, action_name, action_data=[]):
	keys = [table.make_key([gc.KeyTuple(*f)   for f in keys])]
	datas = [table.make_data([gc.DataTuple(*p) for p in action_data],
								  action_name)]
	table.entry_add(target, keys, datas)

def table_mod(target, table, keys, action_name, action_data=[]):
	keys = [table.make_key([gc.KeyTuple(*f)   for f in keys])]
	datas = [table.make_data([gc.DataTuple(*p) for p in action_data],
								  action_name)]
	table.entry_mod(target, keys, datas)

def table_del(target, table, keys):
	table.entry_del(target, keys)

def get_port_status(target, table, keys):
	keys = [table.make_key([gc.KeyTuple(*f)   for f in keys])]
	for data,key in table.entry_get(target,keys):
		key_fields = key.to_dict()
		data_fields = data.to_dict()
		return data_fields['$PORT_UP']

def table_clear(target, table):
	keys = []
	for data,key in table.entry_get(target):
		if key is not None:
			keys.append(key)
	if keys:
		table.entry_del(target, keys)
try:

	grpc_addr = "localhost:50052"
	client_id = 0
	device_id = 0
	pipe_id = 0xFFFF
	is_master = True
	client = gc.ClientInterface(grpc_addr, client_id, device_id)
	target = gc.Target(device_id, pipe_id)
	client.bind_pipeline_config("netlr")
	#client.bind_pipeline_config("harmonia")
	NUM_REPLICA_CTRL = 4
	ip_list = [
	    0x0A000166,
	    0x0A000167,
	    0x0A000168,
		0x0A000169
		]
	port_list = [
	    52,
	    0,
	    4,
		16
	]

	port_table = client.bfrt_info_get().table_get("$PORT")
	num_replica= client.bfrt_info_get().table_get("pipe.num_replica")
	num_replica.entry_add(
		target,
		[num_replica.make_key([gc.KeyTuple('$REGISTER_INDEX', 0)])],
		[num_replica.make_data(
			[gc.DataTuple('num_replica.f1', NUM_REPLICA_CTRL)])])

	stime= time.time()
	num_valid_replica= client.bfrt_info_get().table_get("pipe.num_valid_replica")
	print(time.time() - stime)

	node_table = client.bfrt_info_get().table_get("$pre.node")
	table_clear(target, node_table)
	node_table.entry_add(
		target,
		[node_table.make_key([
			gc.KeyTuple('$MULTICAST_NODE_ID', 1)])],
		[node_table.make_data([
			gc.DataTuple('$MULTICAST_RID', 1),
			gc.DataTuple('$MULTICAST_LAG_ID', int_arr_val=[]),
			#gc.DataTuple('$DEV_PORT', int_arr_val=[128])])]
			gc.DataTuple('$DEV_PORT', int_arr_val=port_list)])]
	)

	mgid_table = client.bfrt_info_get().table_get("$pre.mgid")
	table_clear(target, mgid_table)
	mgid_table.entry_add(
		target,
		[mgid_table.make_key([
			gc.KeyTuple('$MGID', 1)])],
		[mgid_table.make_data([
			gc.DataTuple('$MULTICAST_NODE_ID',  int_arr_val=[1]),
			gc.DataTuple('$MULTICAST_NODE_L1_XID_VALID', bool_arr_val=[0]),
			gc.DataTuple('$MULTICAST_NODE_L1_XID', int_arr_val=[0])])]
	)

	get_cur_rep_id_table = client.bfrt_info_get().table_get("pipe.SwitchIngress.get_cur_rep_id_table")
	table_clear(target, get_cur_rep_id_table)
	for i in range(NUM_REPLICA_CTRL):
		table_add(target, 	get_cur_rep_id_table,[("hdr.ipv4.srcAddr", ip_list[i])],"get_cur_rep_id_action",[("rep_id",i)])


	get_dst_rep_ip_table = client.bfrt_info_get().table_get("pipe.SwitchIngress.get_dst_rep_ip_table")
	table_clear(target, get_dst_rep_ip_table)
	for i in range(NUM_REPLICA_CTRL):
		table_add(target, get_dst_rep_ip_table,[("ig_md.dst_rep_id", i)],"get_dst_rep_ip_action",[("addr",ip_list[i]),("port",port_list[i])])

	netlr_l3_forward = client.bfrt_info_get().table_get("pipe.SwitchIngress.netlr_l3_forward")
	table_clear(target, netlr_l3_forward)
	for i in range(NUM_REPLICA_CTRL):
		table_add(target, netlr_l3_forward,[("hdr.ipv4.dstAddr", ip_list[i])],"ipv4_forward",[("port",port_list[i])]) # 101
	table_add(target, netlr_l3_forward,[("hdr.ipv4.dstAddr", 0x0A00016A)],"ipv4_forward",[("port",176)]) # 106
	table_add(target, netlr_l3_forward,[("hdr.ipv4.dstAddr", 0x0A00016B)],"ipv4_forward",[("port",184)]) # 107


	ipv4_exact = client.bfrt_info_get().table_get("pipe.SwitchIngress.ipv4_exact")
	table_clear(target, ipv4_exact)
	for i in range(NUM_REPLICA_CTRL):
		table_add(target, ipv4_exact,[("hdr.ipv4.dstAddr", ip_list[i])],"ipv4_forward",[("port",port_list[i])]) # 101
	table_add(target, ipv4_exact,[("hdr.ipv4.dstAddr", 0x0A00016A)],"ipv4_forward",[("port",176)]) # 106 Client
	table_add(target, ipv4_exact,[("hdr.ipv4.dstAddr", 0x0A00016B)],"ipv4_forward",[("port",184)]) # 107 Client


	while True:
		sleep(1)
		print("Port monitoring..")
		for i in range(NUM_REPLICA_CTRL):
			if get_port_status(target,port_table,[("$DEV_PORT", port_list[i])]) != True:
				stime = time.time()
				print("Port ID " + str(port_list[i]) + " is Down! Server failure is detected!")
				print("Reconfiguration begins..")
				NUM_REPLICA_CTRL = NUM_REPLICA_CTRL - 1
				num_replica.entry_add(
					target,
					[num_replica.make_key([gc.KeyTuple('$REGISTER_INDEX', 0)])],
					[num_replica.make_data(
						[gc.DataTuple('num_replica.f1', NUM_REPLICA_CTRL)])])
				del ip_list[i]
				del port_list[i]
				table_clear(target, get_dst_rep_ip_table)
				for i in range(NUM_REPLICA_CTRL):
					table_add(target, get_dst_rep_ip_table,[("ig_md.dst_rep_id", i)],"get_dst_rep_ip_action",[("addr",ip_list[i]),("port",port_list[i])])
				table_clear(target, get_cur_rep_id_table)
				for i in range(NUM_REPLICA_CTRL):
					table_add(target, 	get_cur_rep_id_table,[("hdr.ipv4.srcAddr", ip_list[i])],"get_cur_rep_id_action",[("rep_id",i)])
				print((time.time() - stime)*1000*1000)
				print("Reconfiguration finished!")
				break

finally:
	client._tear_down_stream()
