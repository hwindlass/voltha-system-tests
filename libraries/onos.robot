# Copyright 2017-present Open Networking Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# onos common functions

*** Settings ***
Documentation     Library for various utilities
Library           SSHLibrary
Library           String
Library           DateTime
Library           Process
Library           Collections
Library           RequestsLibrary
Library           OperatingSystem

*** Keywords ***
Validate OLT Device in ONOS
    #    FIXME use volt-olts to check that the OLT is ONOS
    [Arguments]    ${serial_number}
    [Documentation]    Checks if olt has been connected to ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    @{serial_numbers}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${sn}=    Get From Dictionary    ${value}    serial
        ${matched}=    Set Variable If    '${sn}' == '${serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${serial_number} found
    [Return]    ${of_id}

Get ONU Port in ONOS
    [Arguments]    ${onu_serial_number}    ${olt_of_id}
    [Documentation]    Retrieves ONU port for the ONU in ONOS
    ${onu_serial_number}=    Catenate    SEPARATOR=-    ${onu_serial_number}    1
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${onu_port}=    Get From Dictionary    ${value}    port
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${onu_serial_number}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for ${onu_serial_number} found
    [Return]    ${onu_port}

Get NNI Port in ONOS
    [Arguments]    ${olt_of_id}
    [Documentation]    Retrieves NNI port for the OLT in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices/${olt_of_id}/ports
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['ports']}
    ${length}=    Get Length    ${jsondata['ports']}
    @{ports}=    Create List
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['ports']}    ${INDEX}
        ${annotations}=    Get From Dictionary    ${value}    annotations
        ${nni_port}=    Get From Dictionary    ${value}    port
        ${nniPortName}=    Catenate    SEPARATOR=    nni-    ${nni_port}
        ${portName}=    Get From Dictionary    ${annotations}    portName
        ${matched}=    Set Variable If    '${portName}' == '${nniPortName}'    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No match for NNI found for ${olt_of_id}
    [Return]    ${nni_port}

Get FabricSwitch in ONOS
    [Documentation]    Returns of_id of the Fabric Switch in ONOS
    ${resp}=    Get Request    ONOS    onos/v1/devices
    ${jsondata}=    To Json    ${resp.content}
    Should Not Be Empty    ${jsondata['devices']}
    ${length}=    Get Length    ${jsondata['devices']}
    ${matched}=    Set Variable    False
    FOR    ${INDEX}    IN RANGE    0    ${length}
        ${value}=    Get From List    ${jsondata['devices']}    ${INDEX}
        ${of_id}=    Get From Dictionary    ${value}    id
        ${type}=    Get From Dictionary    ${value}    type
        ${matched}=    Set Variable If    '${type}' == "SWITCH"    True    False
        Exit For Loop If    ${matched}
    END
    Should Be True    ${matched}    No fabric switch found
    [Return]    ${of_id}

Verify Subscriber Access Flows Added for ONU
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${c_tag}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:0 |
    ...     grep VLAN_ID:${c_tag} | grep transition=TABLE:1
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_0_cmd}
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${c_tag} |
    ...     grep VLAN_ID:0 | grep OUTPUT:${onu_port}
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_1_cmd}
    Should Not Be Empty    ${downstream_flow_1_added}
    # Verify ipv4 dhcp upstream flow
    ${upstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep ETH_TYPE=ipv4 |
    ...     grep VLAN_VID:${c_tag} | grep OUTPUT:CONTROLLER
    ${upstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${upstream_flow_ipv4_cmd}
    # Verify ipv4 dhcp downstream flow
    # Note: This flow will be one per nni per olt
    ${downstream_flow_ipv4_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep ETH_TYPE=ipv4 |
    ...     grep OUTPUT:CONTROLLER
    ${downstream_flow_ipv4_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${downstream_flow_ipv4_cmd}

Verify Subscriber Access Flows Added for ONU DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${onu_port}    ${nni_port}    ${s_tag}
    [Documentation]    Verifies if the Subscriber Access Flows are added in ONOS for the ONU
    # Verify upstream table=0 flow
    ${upstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any | grep transition=TABLE:1
    Should Not Be Empty    ${upstream_flow_0_added}
    # Verify upstream table=1 flow
    ${flow_vlan_push_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${onu_port} | grep VLAN_VID:Any |
    ...     grep VLAN_PUSH | grep VLAN_ID:${s_tag} | grep OUTPUT:${nni_port}
    ${upstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_push_cmd}
    Should Not Be Empty    ${upstream_flow_1_added}
    # Verify downstream table=0 flow
    ${flow_vlan_pop_cmd}=    Catenate    SEPARATOR=
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:${s_tag} |
    ...     grep VLAN_POP | grep transition=TABLE:1
    ${downstream_flow_0_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ${flow_vlan_pop_cmd}
    Should Not Be Empty    ${downstream_flow_0_added}
    # Verify downstream table=1 flow
    ${downstream_flow_1_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep IN_PORT:${nni_port} | grep VLAN_VID:Any | grep OUTPUT:${onu_port}
    Should Not Be Empty    ${downstream_flow_1_added}

Verify Subscriber Access Flows Added Count DT
    [Arguments]    ${ip}    ${port}    ${olt_of_id}    ${expected_flows}
    [Documentation]    Matches for total number of subscriber access flows added for all onus
    ${access_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s ADDED ${olt_of_id} | grep -v deviceId | grep -v ETH_TYPE:lldp | wc -l
    Should Be Equal As Integers    ${access_flows_added}    ${expected_flows}

Verify Device Flows Removed
    [Arguments]    ${ip}    ${port}    ${olt_of_id}
    [Documentation]    Verifies all flows are removed from the device
    ${device_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ${olt_of_id} | grep -v deviceId | wc -l
    Should Be Equal As Integers    ${device_flows}    0

Verify Eapol Flows Added
    [Arguments]    ${ip}    ${port}    ${expected_flows}
    [Documentation]    Matches for number of eapol flows based on number of onus
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT | wc -l
    Should Contain    ${eapol_flows_added}    ${expected_flows}

Verify No Pending Flows For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that there are no flows "PENDING" state for the ONU in ONOS
    ${pending_flows}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s | grep IN_PORT:${onu_port} | grep PENDING
    Should Be Empty    ${pending_flows}

Verify Eapol Flows Added For ONU
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the Eapol Flows are added in ONOS for the ONU
    ${eapol_flows_added}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    flows -s -f ADDED | grep eapol | grep IN_PORT:${onu_port}
    Should Not Be Empty    ${eapol_flows_added}

Verify ONU Port Is Enabled
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the ONU port is enabled in ONOS
    ${onu_port_enabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep port=${onu_port}
    Log    ${onu_port_enabled}
    Should Not Be Empty    ${onu_port_enabled}

Verify ONU Port Is Disabled
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies if the ONU port is disabled in ONOS
    ${onu_port_disabled}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    ports -e | grep port=${onu_port}
    Log    ${onu_port_disabled}
    Should Be Empty    ${onu_port_disabled}

Verify ONU in AAA-Users
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified onu_port exists in aaa-users output
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | grep ${onu_port}
    Should Not Be Empty    ${aaa_users}    ONU port ${onu_port} not found in aaa-users

Verify Number of AAA-Users
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of aaa-users authorized based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${aaa_users}=    Execute ONOS CLI Command    ${ip}    ${port}    aaa-users | grep AUTHORIZED | wc -l
    Should Contain    ${aaa_users}    ${expected_onus}

Validate DHCP Allocations
    [Arguments]    ${ip}    ${port}    ${expected_onus}
    [Documentation]    Matches for number of dhcpacks based on number of onus
    ##TODO: filter by onu serial number instead of count
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}    dhcpl2relay-allocations | grep DHCPACK | wc -l
    Should Contain    ${allocations}    ${expected_onus}

Validate Subscriber DHCP Allocation
    [Arguments]    ${ip}    ${port}    ${onu_port}
    [Documentation]    Verifies that the specified subscriber is found in DHCP allocations
    ##TODO: Enhance the keyword to include DHCP allocated address is not 0.0.0.0
    ${allocations}=    Execute ONOS CLI Command    ${ip}    ${port}
    ...    dhcpl2relay-allocations | grep DHCPACK | grep ${onu_port}
    Should Not Be Empty    ${allocations}    ONU port ${onu_port} not found in dhcpl2relay-allocations

Device Is Available In ONOS
    [Arguments]    ${url}    ${dpid}
    [Documentation]    Validates the device exists and it available in ONOS
    ${rc}    ${json}    Run And Return Rc And Output    curl --fail -sSL ${url}/onos/v1/devices/${dpid}
    Should Be Equal As Integers    0    ${rc}
    ${rc}    ${value}    Run And Return Rc And Output    echo '${json}' | jq -r .available
    Should Be Equal As Integers    0    ${rc}
    Should Be Equal    'true'    '${value}'

Remove All Devices From ONOS
    [Arguments]    ${url}
    [Documentation]    Executes the device-remove command on each device in ONOS
    ${rc}    @{dpids}    Run And Return Rc And Output
    ...    curl --fail -sSL ${url}/onos/v1/devices | jq -r '.devices[].id'
    Should Be Equal As Integers    ${rc}    0
    ${count}=    Get length    ${dpids}
    FOR    ${dpid}    IN    @{dpids}
        ${rc}=    Run Keyword If    '${dpid}' != ''
        ...    Run And Return Rc    curl -XDELETE --fail -sSL ${url}/onos/v1/devices/${dpid}
        Run Keyword If    '${dpid}' != ''
        ...    Should Be Equal As Integers    ${rc}    0
    END
