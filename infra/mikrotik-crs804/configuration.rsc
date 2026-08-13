# Managed CRS804 configuration.
/system identity set name=crs804

# Stage the fabric while the bridge VLAN configuration is updated.
/interface ethernet set [find where name="qsfp56-dd-1-1"] auto-negotiation=no speed=200G-baseCR4 l2mtu=9216 tx-flow-control=on rx-flow-control=on disabled=yes comment="spark-01"
/interface ethernet set [find where name="qsfp56-dd-1-5"] auto-negotiation=no speed=200G-baseCR4 l2mtu=9216 tx-flow-control=on rx-flow-control=on disabled=yes comment="spark-02"
/interface ethernet set [find where name="qsfp56-dd-2-1"] auto-negotiation=no speed=200G-baseCR4 l2mtu=9216 tx-flow-control=on rx-flow-control=on disabled=yes comment="spark-03"
/interface ethernet set [find where name="qsfp56-dd-2-5"] auto-negotiation=no speed=200G-baseCR4 l2mtu=9216 tx-flow-control=on rx-flow-control=on disabled=yes comment="spark-04"

# VLAN 1 is untagged management; VLAN 100 is the untagged Spark fabric.
/interface bridge port set [find where interface="ether1"] disabled=no pvid=1 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged
/interface bridge port set [find where interface="ether2"] disabled=no pvid=1 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged
/interface bridge port
:foreach fabricPort in=[find] do={
  :local interfaceName [get $fabricPort interface]
  :if ([:pick $interfaceName 0 10] = "qsfp56-dd-") do={
    set $fabricPort disabled=yes pvid=100 ingress-filtering=yes frame-types=admit-only-untagged-and-priority-tagged
  }
}
/interface bridge port set [find where interface="qsfp56-dd-1-1"] disabled=no
/interface bridge port set [find where interface="qsfp56-dd-1-5"] disabled=no
/interface bridge port set [find where interface="qsfp56-dd-2-1"] disabled=no
/interface bridge port set [find where interface="qsfp56-dd-2-5"] disabled=no

/interface bridge vlan
:if ([:len [find where comment="managed management VLAN"]] = 0) do={ add bridge=bridge vlan-ids=1 untagged=bridge,ether1,ether2 comment="managed management VLAN" } else={ set [find where comment="managed management VLAN"] bridge=bridge vlan-ids=1 untagged=bridge,ether1,ether2 }
:if ([:len [find where comment="managed fabric VLAN"]] = 0) do={ add bridge=bridge vlan-ids=100 untagged=qsfp56-dd-1-1,qsfp56-dd-1-5,qsfp56-dd-2-1,qsfp56-dd-2-5 comment="managed fabric VLAN" } else={ set [find where comment="managed fabric VLAN"] bridge=bridge vlan-ids=100 untagged=qsfp56-dd-1-1,qsfp56-dd-1-5,qsfp56-dd-2-1,qsfp56-dd-2-5 }

/interface bridge set [find where name="bridge"] vlan-filtering=yes

# Bring up the four Spark links only after isolation is active.
/interface ethernet set [find where name="qsfp56-dd-1-1"] disabled=no
/interface ethernet set [find where name="qsfp56-dd-1-5"] disabled=no
/interface ethernet set [find where name="qsfp56-dd-2-1"] disabled=no
/interface ethernet set [find where name="qsfp56-dd-2-5"] disabled=no
