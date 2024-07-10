param ConnectionName string = 'WasteReductionConnection'
param DisplayName string = 'WasteReductionConnection'

@minLength(1)
param Location string = resourceGroup().location

@minLength(1)
param appName string = 'WasteReductionApp'

resource WasteReduction 'Microsoft.Logic/workflows@2019-05-01' = {
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Week'
            interval: 1
          }
          evaluatedRecurrence: {
            frequency: 'Week'
            interval: 1
          }
          type: 'Recurrence'
        }
      }
      actions: {
        For_each_App_GW: {
          foreach: '@body(\'Parse_Idle_App_Gateways\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)': {
              runAfter: {
                'Set_Email_body_-_App_Gateways': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Idle Application Gateway detected<br>\n<br>\n</strong></u></span><span style="font-size: 12px"><strong>Name: </strong></span>@{items(\'For_each_App_GW\')?[\'name\']}<br>\n<strong>Resource group: </strong>@{items(\'For_each_App_GW\')?[\'resourceGroup\']}<br>\n<strong>Resource URL: </strong>@{variables(\'AppGwURI\')}<br>\n<br>\n<em>Please review if it should be deleted.&nbsp;</em></p>'
                  Subject: 'Idle Application Gateway detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            Set_App_Gateways_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'AppGwURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_App_GW\')?[\'tenantId\'],\'/resource\',items(\'For_each_App_GW\')?[\'id\'])}'
              }
            }
            'Set_Email_body_-_App_Gateways': {
              runAfter: {
                Set_App_Gateways_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-AppGws'
                value: '<h1>Idle Application Gateway detected</h1>\n<b>@{items(\'For_each_App_GW\')?[\'name\']}</b> in resource group <b>@{items(\'For_each_App_GW\')?[\'resourceGroup\']}</b> is Idle\n</br>\nResource URL: @{variables(\'AppGwURI\')}\nPlease review if it should be deleted. '
              }
            }
          }
          runAfter: {
            Initialize_App_Gateways_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_Disk: {
          foreach: '@body(\'Parse_Idle_disks\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)_2': {
              runAfter: {
                'Set_Email_body_-_Disks': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Idle disk detected<br>\n</strong></u></span><br>\n<strong>Name:</strong> @{items(\'For_each_Disk\')?[\'DiskName\']}<br>\n<strong>Resource group:</strong> @{items(\'For_each_Disk\')?[\'resourceGroup\']}<strong><br>\nResource URL:</strong> &nbsp;@{variables(\'DiskURI\')}<br>\n<br>\n<em>Please review if it should be deleted.&nbsp;</em></p>'
                  Subject: 'Idle disk detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            Set_Disk_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'DiskURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Disk\')?[\'tenantId\'],\'/resource\',items(\'For_each_Disk\')?[\'DiskId\'])}'
              }
            }
            'Set_Email_body_-_Disks': {
              runAfter: {
                Set_Disk_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-disks'
                value: '<h1>Idle disk detected</h1>\n<b>@{items(\'For_each_Disk\')?[\'name\']}</b>  in resource group <b>@{items(\'For_each_Disk\')?[\'resourceGroup\']}</b> is unattached.\n</br>\nResource URL:  @{variables(\'DiskURI\')}\nPlease review if it should be deleted. '
              }
            }
          }
          runAfter: {
            Initialize_Disk_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_IP_address: {
          foreach: '@body(\'Parse_Idle_IP_addresses\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)_3': {
              runAfter: {
                'Set_Email_body_-_IP_addresses': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Idle IP address detected<br>\n<br>\n</strong></u></span><strong>Name:</strong> @{items(\'For_each_IP_address\')?[\'IPName\']}<br>\n<strong>Resource group:</strong> @{items(\'For_each_IP_address\')?[\'resourceGroup\']}<br>\n<strong>Resource URL:</strong> &nbsp;@{variables(\'IPAddressURI\')}<br>\n<br>\n<em>Please review if it should be deleted.&nbsp;</em></p>'
                  Subject: 'Idle IP address detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            'Set_Email_body_-_IP_addresses': {
              runAfter: {
                Set_IP_address_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-IP-Addresses'
                value: '<h1>Idle IP address detected</h1>\n<b>@{items(\'For_each_IP_address\')?[\'name\']} </b>  in resource group <b> @{items(\'For_each_IP_address\')?[\'resourceGroup\']}</b> is unattached.\n</br>Resource URL:  @{variables(\'IPAddressURI\')}\nPlease review if it should be deleted. '
              }
            }
            Set_IP_address_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'IPAddressURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_IP_address\')?[\'tenantId\'],\'/resource\',items(\'For_each_IP_address\')?[\'PublicIpId\'])}'
              }
            }
          }
          runAfter: {
            Initialize_IP_addresses_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_Load_Balancer: {
          foreach: '@body(\'Parse_Idle_Load_Balancers\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)_4': {
              runAfter: {
                'Set_Email_body_-_Load_Balancers': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Idle Load Balancer detected<br>\n<br>\n</strong></u></span><strong>Name:</strong> @{items(\'For_each_Load_Balancer\')?[\'LoadBalancerName\']}<br>\n<strong>Resource group:</strong> @{items(\'For_each_Load_Balancer\')?[\'resourceGroup\']}<strong><br>\nResource URL:</strong> &nbsp;@{variables(\'LoadBalancerURI\')}<br>\n<br>\n<em>Please review if it should be deleted.&nbsp;</em></p>'
                  Subject: 'Idle Load Balancer detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            'Set_Email_body_-_Load_Balancers': {
              runAfter: {
                Set_Load_Balancer_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-LoadBalancers'
                value: '<h1>Idle Lod Balancer detected</h1>\n<b>@{items(\'For_each_Load_Balancer\')?[\'name\']}</b>  in resource group <b>@{items(\'For_each_Load_Balancer\')?[\'resourceGroup\']}</b> is Idle.\n</br>\nResource URL:  @{variables(\'LoadBalancerURI\')}\nPlease review if it should be deleted. '
              }
            }
            Set_Load_Balancer_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'LoadBalancerURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Load_Balancer\')?[\'tenantId\'],\'/resource\',items(\'For_each_Load_Balancer\')?[\'loadBalancerid\'])}'
              }
            }
          }
          runAfter: {
            Initialize_Load_Balancer_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_Snapshot: {
          foreach: '@body(\'Parse_Snapshots\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)_6': {
              runAfter: {
                'Set_Email_body_-_Snapshot': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Old Disk Snapshot detected<br>\n<br>\n</strong></u></span><span style="font-size: 12px"><strong>Name: </strong></span><span style="font-size: 12px"><strong>@{items(\'For_each_Snapshot\')?[\'Snapshotname\']}</strong></span><span style="font-size: 12px"><strong><br>\nResource Group: </strong></span><span style="font-size: 12px"><strong>@{items(\'For_each_Snapshot\')?[\'resourceGroup\']}</strong></span><span style="font-size: 12px"><strong><br>\nResource URL: </strong></span><span style="font-size: 12px"><strong>@{variables(\'SnapshotURI\')}</strong></span><span style="font-size: 12px"><strong><br>\n<br>\n</strong></span><span style="font-size: 12px"><em>Please review if it should be deleted.&nbsp;<br>\n</em></span></p>'
                  Subject: 'Disk Snapshot older than 30 days detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            'Set_Email_body_-_Snapshot': {
              runAfter: {
                Set_Snapshot_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-Snapshots'
                value: '<h1>Idle Snapshot detected</h1>\n<b> @{items(\'For_each_Snapshot\')?[\'name\']} </b>  in resource group <b>@{items(\'For_each_Snapshot\')?[\'resourceGroup\']}</b> is Idle.\n</br>\nResource URL:  @{variables(\'SnapshotURI\')}\nPlease review if it should be deleted. '
              }
            }
            Set_Snapshot_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'SnapshotURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Snapshot\')?[\'tenantId\'],\'/resource\',items(\'For_each_Snapshot\')?[\'SnapshotId\'])}\n'
              }
            }
          }
          runAfter: {
            Initialize_Snapshot_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        For_each_Stopped_VM: {
          foreach: '@body(\'Parse_Stopped_VMs\')?[\'data\']'
          actions: {
            'Send_an_email_(V2)_5': {
              runAfter: {
                'Set_Email_body_-_Stopped_VM': [
                  'Succeeded'
                ]
              }
              type: 'ApiConnection'
              inputs: {
                body: {
                  Body: '<p><span style="font-size: 24px"><u><strong>Stopped VM detected<br>\n<br>\n</strong></u></span><strong>Name:</strong> @{items(\'For_each_Stopped_VM\')?[\'VMname\']}<br>\n<strong>Resource group:</strong> @{items(\'For_each_Stopped_VM\')?[\'resourceGroup\']}<br>\n<strong>Resource URL: &nbsp;</strong>@{variables(\'StoppedVMURI\')}<br>\n<br>\n<em>Please review if it should be deleted.&nbsp;</em></p>'
                  Subject: 'Stopped VM detected'
                  To: '@variables(\'SendAlertTo\')'
                }
                host: {
                  connection: {
                    name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
                  }
                }
                method: 'post'
                path: '/v2/Mail'
              }
            }
            'Set_Email_body_-_Stopped_VM': {
              runAfter: {
                Set_Stopped_VM_URI: [
                  'Succeeded'
                ]
              }
              type: 'SetVariable'
              inputs: {
                name: 'EmailBody-StoppedVMs'
                value: '<h1>Stopped VM detected</h1>\n<b> @{items(\'For_each_Stopped_VM\')?[\'name\']}</b>  in resource group <b> @{items(\'For_each_Stopped_VM\')?[\'resourceGroup\']}</b> is Idle.\n</br>\nResource URL:  @{variables(\'StoppedVMURI\')}\nPlease review if it should be deleted. '
              }
            }
            Set_Stopped_VM_URI: {
              runAfter: {}
              type: 'SetVariable'
              inputs: {
                name: 'StoppedVMURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Stopped_VM\')?[\'tenantId\'],\'/resource\',items(\'For_each_Stopped_VM\')?[\'VirtualMachineId\'])}'
              }
            }
          }
          runAfter: {
            Initialize_Stopped_VM_URI: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
        Get_Idle_App_Gateways: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources| where type =~ \'Microsoft.Network/applicationGateways\'| extend backendPoolsCount = array_length(properties.backendAddressPools),SKUName= tostring(properties.sku.name), SKUTier=tostring(properties.sku.tier),SKUCapacity=properties.sku.capacity,backendPools=properties.backendAddressPools|  join (resources | where type =~ \'Microsoft.Network/applicationGateways\'| mvexpand backendPools = properties.backendAddressPools| extend backendIPCount =array_length(backendPools.properties.backendIPConfigurations) | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses) | extend backendPoolName=backendPools.properties.backendAddressPools.name | summarize backendIPCount = sum(backendIPCount) ,backendAddressesCount=sum(backendAddressesCount) by id) on id| project-away id1| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))| order by id asc'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Get_Idle_Disks: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources | where type =~ \'microsoft.compute/disks\' and managedBy == \'\'| extend diskState = tostring(properties.diskState) | where managedBy == \'\' and diskState != \'ActiveSAS\' or diskState == \'Unattached\' and diskState != \'ActiveSAS\' | extend DiskId=id, DiskName=name, SKUName=sku.name, SKUTier=sku.tier, DiskSizeGB=tostring(properties.diskSizeGB), Location=location, TimeCreated=tostring(properties.timeCreated) | order by DiskId asc  | project DiskId, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Get_Idle_IP_addresses: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources | where type =~ \'Microsoft.Network/publicIPAddresses\' and isempty(properties.ipConfiguration) and isempty(properties.natGateway) | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location | project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, tenantId | union ( Resources | where type =~ \'microsoft.network/networkinterfaces\' and isempty(properties.virtualMachine) and isnull(properties.privateEndpoint) and isnotempty(properties.ipConfigurations) | extend IPconfig = properties.ipConfigurations | mv-expand IPconfig | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id) | project PublicIpId | join (  resources | where type =~ \'Microsoft.Network/publicIPAddresses\' | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, resourceGroup, Location=location  ) on PublicIpId | project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, tenantId)'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Get_Idle_Load_Balancers: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources | where type =~ \'microsoft.network/loadbalancers\' and tostring(properties.backendAddressPools) == \'[]\' | extend loadBalancerId=id,LBRG=resourceGroup, LoadBalancerName=name, SKU=sku, LBLocation=location | order by loadBalancerId asc | project loadBalancerId,LoadBalancerName, SKU.name,SKU.tier, LBLocation, resourceGroup, subscriptionId'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Get_Disk_Snapshots_older_than_30_days: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources | where type =~ \'microsoft.compute/snapshots\' | extend TimeCreated = properties.timeCreated | where TimeCreated < ago(30d) | extend SnapshotId=id, Snapshotname=name | order by id asc | project id, SnapshotId, Snapshotname, resourceGroup, location, TimeCreated ,subscriptionId'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Get_Stopped_VMs: {
          runAfter: {
            Initialize_Subscriptions: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              type: 'ManagedServiceIdentity'
            }
            body: {
              query: 'resources | where type =~ \'microsoft.compute/virtualmachines\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM deallocated\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM running\'| extend  VMname=name, PowerState=tostring(properties.extended.instanceView.powerState.displayStatus), VMLocation=location, VirtualMachineId=id| order by VirtualMachineId asc| project VirtualMachineId,VMname, PowerState, VMLocation, resourceGroup, subscriptionId'
              subscriptions: '@variables(\'Subscriptions\')'
            }
            method: 'POST'
            uri: 'https://management.azure.com/providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
          }
        }
        Initialize_App_Gateways_URI: {
          runAfter: {
            Initialize_App_Gateways_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'AppGwURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_App_Gateways_emailBody: {
          runAfter: {
            Parse_Idle_App_Gateways: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-AppGws'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Disk_URI: {
          runAfter: {
            Initialize_Disks_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'DiskURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Disks_emailBody: {
          runAfter: {
            Parse_Idle_disks: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-disks'
                type: 'string'
              }
            ]
          }
        }
        Initialize_IP_addresses_URI: {
          runAfter: {
            Initialize_IP_addresses_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'IPAddressURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_IP_addresses_emailBody: {
          runAfter: {
            Parse_Idle_IP_addresses: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-IP-Addresses'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Load_Balancer_URI: {
          runAfter: {
            Initialize_Load_balancers_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'LoadBalancerURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Load_balancers_emailBody: {
          runAfter: {
            Parse_Idle_Load_Balancers: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-LoadBalancers'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Snapshot_URI: {
          runAfter: {
            Initialize_Snapshots_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SnapshotURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Snapshots_emailBody: {
          runAfter: {
            Parse_Snapshots: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-Snapshots'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Stopped_VM_URI: {
          runAfter: {
            Initialize_Stopped_VMs_emailBody: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'StoppedVMURI'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Stopped_VMs_emailBody: {
          runAfter: {
            Parse_Stopped_VMs: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailBody-StoppedVMs'
                type: 'string'
              }
            ]
          }
        }
        Initialize_Subscriptions: {
          runAfter: {
            Set_Alert_receipient: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'Subscriptions'
                type: 'array'
                value: [
                  ''
                ]
              }
            ]
          }
        }
        Parse_Idle_App_Gateways: {
          runAfter: {
            Get_Idle_App_Gateways: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Idle_App_Gateways\')'
            schema: {
              properties: {
                properties: {
                  properties: {
                    count: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    data: {
                      properties: {
                        items: {
                          properties: {
                            properties: {
                              properties: {
                                SKUCapacity: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                SKUName: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                SKUTier: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                backendAddressesCount: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                backendIPCount: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                backendPools: {
                                  properties: {
                                    items: {
                                      properties: {
                                        properties: {
                                          properties: {
                                            etag: {
                                              properties: {
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            id: {
                                              properties: {
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            name: {
                                              properties: {
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            properties: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    backendAddresses: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    provisioningState: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    requestRoutingRules: {
                                                      properties: {
                                                        items: {
                                                          properties: {
                                                            properties: {
                                                              properties: {
                                                                id: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            required: {
                                                              items: {
                                                                type: 'string'
                                                              }
                                                              type: 'array'
                                                            }
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              properties: {
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        required: {
                                          items: {
                                            type: 'string'
                                          }
                                          type: 'array'
                                        }
                                        type: {
                                          type: 'string'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                backendPoolsCount: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                extendedLocation: {
                                  properties: {}
                                  type: 'object'
                                }
                                id: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                identity: {
                                  properties: {}
                                  type: 'object'
                                }
                                kind: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                location: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                managedBy: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                name: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                plan: {
                                  properties: {}
                                  type: 'object'
                                }
                                properties: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        authenticationCertificates: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        backendAddressPools: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            backendAddresses: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            requestRoutingRules: {
                                                              properties: {
                                                                items: {
                                                                  properties: {
                                                                    properties: {
                                                                      properties: {
                                                                        id: {
                                                                          properties: {
                                                                            type: {
                                                                              type: 'string'
                                                                            }
                                                                          }
                                                                          type: 'object'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                    required: {
                                                                      items: {
                                                                        type: 'string'
                                                                      }
                                                                      type: 'array'
                                                                    }
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        backendHttpSettingsCollection: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            cookieBasedAffinity: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            pickHostNameFromBackendAddress: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            port: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            protocol: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            requestRoutingRules: {
                                                              properties: {
                                                                items: {
                                                                  properties: {
                                                                    properties: {
                                                                      properties: {
                                                                        id: {
                                                                          properties: {
                                                                            type: {
                                                                              type: 'string'
                                                                            }
                                                                          }
                                                                          type: 'object'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                    required: {
                                                                      items: {
                                                                        type: 'string'
                                                                      }
                                                                      type: 'array'
                                                                    }
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            requestTimeout: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        enableHttp2: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        frontendIPConfigurations: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            httpListeners: {
                                                              properties: {
                                                                items: {
                                                                  properties: {
                                                                    properties: {
                                                                      properties: {
                                                                        id: {
                                                                          properties: {
                                                                            type: {
                                                                              type: 'string'
                                                                            }
                                                                          }
                                                                          type: 'object'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                    required: {
                                                                      items: {
                                                                        type: 'string'
                                                                      }
                                                                      type: 'array'
                                                                    }
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            privateIPAllocationMethod: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            subnet: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        frontendPorts: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            httpListeners: {
                                                              properties: {
                                                                items: {
                                                                  properties: {
                                                                    properties: {
                                                                      properties: {
                                                                        id: {
                                                                          properties: {
                                                                            type: {
                                                                              type: 'string'
                                                                            }
                                                                          }
                                                                          type: 'object'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                    required: {
                                                                      items: {
                                                                        type: 'string'
                                                                      }
                                                                      type: 'array'
                                                                    }
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            port: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        gatewayIPConfigurations: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            subnet: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        httpListeners: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            frontendIPConfiguration: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            frontendPort: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            protocol: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            requestRoutingRules: {
                                                              properties: {
                                                                items: {
                                                                  properties: {
                                                                    properties: {
                                                                      properties: {
                                                                        id: {
                                                                          properties: {
                                                                            type: {
                                                                              type: 'string'
                                                                            }
                                                                          }
                                                                          type: 'object'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                    required: {
                                                                      items: {
                                                                        type: 'string'
                                                                      }
                                                                      type: 'array'
                                                                    }
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            requireServerNameIndication: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        operationalState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        probes: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        provisioningState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        redirectConfigurations: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        requestRoutingRules: {
                                          properties: {
                                            items: {
                                              properties: {
                                                properties: {
                                                  properties: {
                                                    etag: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    id: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    name: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    properties: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            backendAddressPool: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            backendHttpSettings: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            httpListener: {
                                                              properties: {
                                                                properties: {
                                                                  properties: {
                                                                    id: {
                                                                      properties: {
                                                                        type: {
                                                                          type: 'string'
                                                                        }
                                                                      }
                                                                      type: 'object'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            provisioningState: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            ruleType: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      properties: {
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                required: {
                                                  items: {
                                                    type: 'string'
                                                  }
                                                  type: 'array'
                                                }
                                                type: {
                                                  type: 'string'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        resourceGuid: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        rewriteRuleSets: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        sku: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                capacity: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                name: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                tier: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        sslCertificates: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        urlPathMaps: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                resourceGroup: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                sku: {
                                  properties: {}
                                  type: 'object'
                                }
                                subscriptionId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                tags: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                tenantId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                type: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                zones: {
                                  properties: {}
                                  type: 'object'
                                }
                              }
                              type: 'object'
                            }
                            required: {
                              items: {
                                type: 'string'
                              }
                              type: 'array'
                            }
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    facets: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    resultTruncated: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    totalRecords: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                  }
                  type: 'object'
                }
                type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_Idle_IP_addresses: {
          runAfter: {
            Get_Idle_IP_addresses: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Idle_IP_addresses\')'
            schema: {
              properties: {
                properties: {
                  properties: {
                    count: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    data: {
                      properties: {
                        items: {
                          properties: {
                            properties: {
                              properties: {
                                extendedLocation: {
                                  properties: {}
                                  type: 'object'
                                }
                                id: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                identity: {
                                  properties: {}
                                  type: 'object'
                                }
                                kind: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                location: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                managedBy: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                name: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                plan: {
                                  properties: {}
                                  type: 'object'
                                }
                                properties: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        idleTimeoutInMinutes: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        ipTags: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        provisioningState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        publicIPAddressVersion: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        publicIPAllocationMethod: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        resourceGuid: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                resourceGroup: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                sku: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        name: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        tier: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                subscriptionId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                tags: {
                                  properties: {}
                                  type: 'object'
                                }
                                tenantId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                type: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                zones: {
                                  properties: {}
                                  type: 'object'
                                }
                              }
                              type: 'object'
                            }
                            required: {
                              items: {
                                type: 'string'
                              }
                              type: 'array'
                            }
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    facets: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    resultTruncated: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    totalRecords: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                  }
                  type: 'object'
                }
                type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_Idle_Load_Balancers: {
          runAfter: {
            Get_Idle_Load_Balancers: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Idle_Load_Balancers\')'
            schema: {
              properties: {
                items: {
                  properties: {
                    properties: {
                      properties: {
                        childErrors: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        errorType: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        lineNumber: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        linePosition: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        message: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        path: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        schemaId: {
                          properties: {
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        value: {
                          properties: {
                            items: {
                              properties: {
                                type: {
                                  type: 'string'
                                }
                              }
                              type: 'object'
                            }
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                      }
                      type: 'object'
                    }
                    required: {
                      items: {
                        type: 'string'
                      }
                      type: 'array'
                    }
                    type: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
                type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_Idle_disks: {
          runAfter: {
            Get_Idle_Disks: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Idle_Disks\')'
            schema: {
              properties: {
                properties: {
                  properties: {
                    count: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    data: {
                      properties: {
                        items: {
                          properties: {
                            properties: {
                              properties: {
                                extendedLocation: {
                                  properties: {}
                                  type: 'object'
                                }
                                id: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                identity: {
                                  properties: {}
                                  type: 'object'
                                }
                                kind: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                location: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                managedBy: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                name: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                plan: {
                                  properties: {}
                                  type: 'object'
                                }
                                properties: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        creationData: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                createOption: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                imageReference: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        id: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        diskIOPSReadWrite: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        diskMBpsReadWrite: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        diskSizeBytes: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        diskSizeGB: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        diskState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        encryption: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                type: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        hyperVGeneration: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        networkAccessPolicy: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        osType: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        provisioningState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        publicNetworkAccess: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        supportedCapabilities: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                architecture: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        timeCreated: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        uniqueId: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                resourceGroup: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                sku: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        name: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        tier: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                subscriptionId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                tags: {
                                  properties: {}
                                  type: 'object'
                                }
                                tenantId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                type: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                zones: {
                                  properties: {}
                                  type: 'object'
                                }
                              }
                              type: 'object'
                            }
                            required: {
                              items: {
                                type: 'string'
                              }
                              type: 'array'
                            }
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    facets: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    resultTruncated: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    totalRecords: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                  }
                  type: 'object'
                }
                type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_Snapshots: {
          runAfter: {
            Get_Disk_Snapshots_older_than_30_days: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Disk_Snapshots_older_than_30_days\')'
            schema: {
              properties: {
                query: {
                  type: 'string'
                }
                subscriptions: {
                  items: {
                    type: 'string'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
        Parse_Stopped_VMs: {
          runAfter: {
            Get_Stopped_VMs: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_Stopped_VMs\')'
            schema: {
              properties: {
                properties: {
                  properties: {
                    count: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    data: {
                      properties: {
                        items: {
                          properties: {
                            properties: {
                              properties: {
                                extendedLocation: {
                                  properties: {}
                                  type: 'object'
                                }
                                id: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                identity: {
                                  properties: {}
                                  type: 'object'
                                }
                                kind: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                location: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                managedBy: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                name: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                plan: {
                                  properties: {}
                                  type: 'object'
                                }
                                properties: {
                                  properties: {
                                    properties: {
                                      properties: {
                                        diagnosticsProfile: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                bootDiagnostics: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        enabled: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        extended: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                instanceView: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        hyperVGeneration: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        powerState: {
                                                          properties: {
                                                            properties: {
                                                              properties: {
                                                                code: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                displayStatus: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                level: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        hardwareProfile: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                vmSize: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        networkProfile: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                networkInterfaces: {
                                                  properties: {
                                                    items: {
                                                      properties: {
                                                        properties: {
                                                          properties: {
                                                            id: {
                                                              properties: {
                                                                type: {
                                                                  type: 'string'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        required: {
                                                          items: {
                                                            type: 'string'
                                                          }
                                                          type: 'array'
                                                        }
                                                        type: {
                                                          type: 'string'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        osProfile: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                adminUsername: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                allowExtensionOperations: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                computerName: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                requireGuestProvisionSignal: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                secrets: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                windowsConfiguration: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        enableAutomaticUpdates: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        patchSettings: {
                                                          properties: {
                                                            properties: {
                                                              properties: {
                                                                assessmentMode: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                enableHotpatching: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                patchMode: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        provisionVMAgent: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        provisioningState: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        storageProfile: {
                                          properties: {
                                            properties: {
                                              properties: {
                                                dataDisks: {
                                                  properties: {
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                imageReference: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        exactVersion: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        offer: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        publisher: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        sku: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        version: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                                osDisk: {
                                                  properties: {
                                                    properties: {
                                                      properties: {
                                                        caching: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        createOption: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        deleteOption: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        diskSizeGB: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        managedDisk: {
                                                          properties: {
                                                            properties: {
                                                              properties: {
                                                                id: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                                storageAccountType: {
                                                                  properties: {
                                                                    type: {
                                                                      type: 'string'
                                                                    }
                                                                  }
                                                                  type: 'object'
                                                                }
                                                              }
                                                              type: 'object'
                                                            }
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        name: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                        osType: {
                                                          properties: {
                                                            type: {
                                                              type: 'string'
                                                            }
                                                          }
                                                          type: 'object'
                                                        }
                                                      }
                                                      type: 'object'
                                                    }
                                                    type: {
                                                      type: 'string'
                                                    }
                                                  }
                                                  type: 'object'
                                                }
                                              }
                                              type: 'object'
                                            }
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                        vmId: {
                                          properties: {
                                            type: {
                                              type: 'string'
                                            }
                                          }
                                          type: 'object'
                                        }
                                      }
                                      type: 'object'
                                    }
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                resourceGroup: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                sku: {
                                  properties: {}
                                  type: 'object'
                                }
                                subscriptionId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                tags: {
                                  properties: {}
                                  type: 'object'
                                }
                                tenantId: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                type: {
                                  properties: {
                                    type: {
                                      type: 'string'
                                    }
                                  }
                                  type: 'object'
                                }
                                zones: {
                                  properties: {}
                                  type: 'object'
                                }
                              }
                              type: 'object'
                            }
                            required: {
                              items: {
                                type: 'string'
                              }
                              type: 'array'
                            }
                            type: {
                              type: 'string'
                            }
                          }
                          type: 'object'
                        }
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    facets: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    resultTruncated: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                    totalRecords: {
                      properties: {
                        type: {
                          type: 'string'
                        }
                      }
                      type: 'object'
                    }
                  }
                  type: 'object'
                }
                type: {
                  type: 'string'
                }
              }
              type: 'object'
            }
          }
        }
        Set_Alert_receipient: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SendAlertTo'
                type: 'string'
                value: ''
              }
            ]
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          office365: {
            connectionId: office365_1_Connection.id
            connectionName: ConnectionName
            id: '${subscription().id}/providers/Microsoft.Web/locations/${Location}/managedApis/office365'
          }
        }
      }
    }
  }
  name: appName
  location: Location
  tags: {
    displayName: 'WasteReduction'
  }
}

resource office365_1_Connection 'MICROSOFT.WEB/CONNECTIONS@2018-07-01-preview' = {
  name: ConnectionName
  location: Location
  properties: {
    api: {
      id: '${subscription().id}/providers/Microsoft.Web/locations/${Location}/managedApis/office365'
    }
    displayName: DisplayName
  }
}
