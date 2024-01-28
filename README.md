# Overview
This is the artifact that is used to evaluate NetLR, as described in the paper "In-Network Leaderless Replication for Distributed Data Stores" in VLDB 2022.
NetLR performs data replication in the programmable switch.

# Contents

This repository contains the following code segments:

1. Switch data plane code
2. Switch control plane code
   - Python2 version (controller_vldb_ver.py, VLDB'22 version with SDE 9.2)
   - Python3 version (controller_python3.py, as of 2024/01/28) // Please use this one with SDE 9.7 now because python2 is deprecated
- Client-server application codes are not public, since we are unable to make the code work in our latest testbed environments due to lots of deprecated features. We believe that people can write a simple client-server application at ease since our core mechanism is in the switch, not in the client/server application.

# Contents

# Hardware dependencies

- To run experiments using the artifact, at least 3 nodes (1 client and 2 servers) are required.
- A programmable switch with Intel Tofino1 ASIC is needed.

# Software dependencies
Our artifact is tested on:

**Switch:**
- Ubuntu 20.04 LTS with Linux kernel 5.4.
- python 2.7
- Intel P4 Studio SDE 9.2.0 and BSP 9.2.0. 

We also tested our artifact on:
- Ubuntu 20.04 LTS with Linux kernel 5.4.
- python 3.8.10
- Intel P4 Studio SDE 9.7.0 and BSP 9.7.0.
  
# Installation

## Switch-side
1. Place `controller_vldb_ver.py`, `controller_python3.py` and `netlr.p4` in the SDE directory.
2. Configure cluster-related information in the `controller_vldb_ver.py` or `controller_python3.py`. This includes IP addresses and port-related information.
     
3. Compile `netlr.p4` using the P4 compiler (we used `p4build.sh` provided by Intel). You can compile it manually with the following commands.
   - `cmake ${SDE}/p4studio -DCMAKE_INSTALL_PREFIX=${SDE_INSTALL} -DCMAKE_MODULE_PATH=${SDE}/cmake -DP4_NAME=netlr -DP4_PATH=${SDE}/netlr.p4`
   - `make`
   - `make install`
   - `${SDE}` and `${SDE_INSTALL}` are path to the SDE. In our testbed, SDE = `/home/admin/bf-sde-9.7.0`  and SDE_INSTALL = `/home/admin/bf-sde-9.7.0/install`.
   - If done well, you should see the following outputs
   ```
   -- 
   P4_LANG: p4-16
   P4C: /home/tofino/bf-sde-9.7.0/install/bin/bf-p4c
   P4C-GEN_BRFT-CONF: /home/tofino/bf-sde-9.7.0/install/bin/p4c-gen-bfrt-conf
   P4C-MANIFEST-CONFIG: /home/tofino/bf-sde-9.7.0/install/bin/p4c-manifest-config
   -- 
   P4_NAME: netlr
   -- 
   P4_PATH: /home/tofino/bf-sde-9.7.0/netlr.p4
   -- Configuring done
   -- Generating done
   -- Build files have been written to: /home/tofino/bf-sde-9.7.0
   [  0%] Built target bf-p4c
   [  0%] Built target driver
   [100%] Generating netlr/tofino/bf-rt.json
   /home/tofino/bf-sde-9.7.0/netlr.p4(186): [--Wwarn=unused] warning: Table update_lseq_table is not used; removing
       table update_lseq_table{
             ^^^^^^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(313): [--Wwarn=unused] warning: Table get_valid_replica_table is not used; removing
       table get_valid_replica_table{
             ^^^^^^^^^^^^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(177): [--Wwarn=unused] warning: update_lseq: unused instance
       RegisterAction<bit<32>, _, bit<32>>(lseq) update_lseq = {
                                                 ^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(303): [--Wwarn=unused] warning: get_valid_replica: unused instance
       RegisterAction<bit<8>, _, bit<8>>(num_valid_replica) get_valid_replica = {
                                                            ^^^^^^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(122): [--Wwarn=uninitialized_out_param] warning: out parameter 'ig_md' may be uninitialized when 'SwitchIngressParser' terminates
           out metadata_t ig_md,
                          ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(119)
   parser SwitchIngressParser(
          ^^^^^^^^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(178): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                                                           ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(178)
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(244): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                                                           ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(244)
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(322): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<8> reg_value, out bit<8> return_value) {
                                                         ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(322)
           void apply(inout bit<8> reg_value, out bit<8> return_value) {
                ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(342): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                                                           ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(342)
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(467): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                                                           ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(467)
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                ^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(487): [--Wwarn=uninitialized_out_param] warning: out parameter 'return_value' may be uninitialized when 'apply' terminates
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                                                           ^^^^^^^^^^^^
   /home/tofino/bf-sde-9.7.0/netlr.p4(487)
           void apply(inout bit<32> reg_value, out bit<32> return_value) {
                ^^^^^
   [100%] Built target netlr-tofino
   [100%] Built target netlr
   [  0%] Built target bf-p4c
   [  0%] Built target driver
   [100%] Built target netlr-tofino
   [100%] Built target netlr
   Install the project...
   -- Install configuration: "RelWithDebInfo"
   -- Up-to-date: /home/tofino/bf-sde-9.7.0/install/share/p4/targets/tofino
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/p4/targets/tofino/netlr.conf
   -- Up-to-date: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr
   -- Up-to-date: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/pipe
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/pipe/tofino.bin
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/pipe/context.json
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/events.json
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/source.json
   -- Installing: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/bf-rt.json

   ```
# Experiment workflow
## Switch-side
1. Open three terminals for the switch control plane. We need them for 1) starting the switch program, 2) port configuration, 3) rule configuration by controller
2. In terminal 1, run netlr program using `run_switchd.sh -p netlr` in the SDE directory. `run_switch.sh` is included in the SDE by default.
- The output should be like...
```
Using SDE /home/tofino/bf-sde-9.7.0
Using SDE_INSTALL /home/tofino/bf-sde-9.7.0/install
Setting up DMA Memory Pool
Using TARGET_CONFIG_FILE /home/tofino/bf-sde-9.7.0/install/share/p4/targets/tofino/netlr.conf
Using PATH /home/tofino/bf-sde-9.7.0/install/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin:/home/tofino/bf-sde-9.7.0/install/bin
Using LD_LIBRARY_PATH /usr/local/lib:/home/tofino/bf-sde-9.7.0/install/lib::/home/tofino/bf-sde-9.7.0/install/lib
bf_sysfs_fname /sys/class/bf/bf0/device/dev_add
Install dir: /home/tofino/bf-sde-9.7.0/install (0x55a86a068bd0)
bf_switchd: system services initialized
bf_switchd: loading conf_file /home/tofino/bf-sde-9.7.0/install/share/p4/targets/tofino/netlr.conf...
bf_switchd: processing device configuration...
Configuration for dev_id 0
  Family        : tofino
  pci_sysfs_str : /sys/devices/pci0000:00/0000:00:03.0/0000:05:00.0
  pci_domain    : 0
  pci_bus       : 5
  pci_fn        : 0
  pci_dev       : 0
  pci_int_mode  : 1
  sbus_master_fw: /home/tofino/bf-sde-9.7.0/install/
  pcie_fw       : /home/tofino/bf-sde-9.7.0/install/
  serdes_fw     : /home/tofino/bf-sde-9.7.0/install/
  sds_fw_path   : /home/tofino/bf-sde-9.7.0/install/share/tofino_sds_fw/avago/firmware
  microp_fw_path: 
bf_switchd: processing P4 configuration...
P4 profile for dev_id 0
num P4 programs 1
  p4_name: netlr
  p4_pipeline_name: pipe
    libpd: 
    libpdthrift: 
    context: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/pipe/context.json
    config: /home/tofino/bf-sde-9.7.0/install/share/tofinopd/netlr/pipe/tofino.bin
  Pipes in scope [0 1 2 3 ]
  diag: 
  accton diag: 
  Agent[0]: /home/tofino/bf-sde-9.7.0/install/lib/libpltfm_mgr.so
  non_default_port_ppgs: 0
  SAI default initialize: 1 
bf_switchd: library /home/tofino/bf-sde-9.7.0/install/lib/libpltfm_mgr.so loaded
bf_switchd: agent[0] initialized
Health monitor started 
Operational mode set to ASIC
Initialized the device types using platforms infra API
ASIC detected at PCI /sys/class/bf/bf0/device
ASIC pci device id is 16
Starting PD-API RPC server on port 9090
bf_switchd: drivers initialized
Setting core_pll_ctrl0=cd44cbfe
/
bf_switchd: dev_id 0 initialized

bf_switchd: initialized 1 devices
Adding Thrift service for bf-platforms to server
bf_switchd: thrift initialized for agent : 0
bf_switchd: spawning cli server thread
bf_switchd: spawning driver shell
bf_switchd: server started - listening on port 9999
bfruntime gRPC server started on 0.0.0.0:50052

        ********************************************
        *      WARNING: Authorised Access Only     *
        ********************************************
    

bfshell> 

```
3. In terminal 2, configure ports manually or `run_bfshell.sh`. It is recommended to configure ports to 100Gbps.
 - After starting the switch program, run `./run_bfshell.sh` and type `ucli` and `pm`.
 - You can create ports like `port-add #/- 100G NONE` and `port-enb #/-`. It is recommended to turn off auto-negotiation using `an-set -/- 2`. This part requires knowledge of Intel Tofino-related stuff. You can find more information in the switch manual or on Intel websites.
4. In terminal 3, run the controller using `python3 controller_python3.py` in the SDE directory for the minimal working example.
- The output should be ...
```
Subscribe attempt #1
Subscribe response received 0
Binding with p4_name netlr
Binding with p4_name netlr successful!!
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
0.0671393871307373
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Received netlr on GetForwarding on client 0, device 0
Port monitoring..

```

# Citation

Please cite this work if you refer to or use any part of this artifact for your research. 

BibTex:

    @article{NetLR,
        author = {Kim, Gyuyeong and Lee, Wonjun},
        title = {In-Network Leaderless Replication for Distributed Data Stores},
        year = {2022},
        issue_date = {March 2022},
        publisher = {VLDB Endowment},
        volume = {15},
        number = {7},
        issn = {2150-8097},
        journal = {Proc. VLDB Endow.},
        month = {Mar.},
        pages = {1337-1349},
        numpages = {13}
    }
