//==============================================================================
// Parameters
//==============================================================================
@description('Azure location where resources should be created')
param location string = resourceGroup().location

@description('Name of the logic app')
@minLength(1)
@maxLength(20)
param appName string = 'finops-alerts'

@description('Specifies the frequency of the recurrence trigger. Possible values are Week, Day or Hour.')
param recurrenceFrequency string = 'Week'

@description('Specifies the interval for the recurrence trigger. Represents the number of frequency units.')
param recurrenceInterval int = 1

@description('Specifies the type of the trigger. For this example, it is a recurrence trigger.')
param recurrenceType string = 'Recurrence'

//==============================================================================
// Variables
//==============================================================================
var safeSuffix = replace(replace(toLower(appName), '-', ''), '_', '')


@description('Name of the connection to use for the logic app')
var connectionName = '${safeSuffix}-connection'

@description('Display name of the connection')
var displayName = '${safeSuffix}-connection'

//Only one actionKey will be needed here after updating the code
@description('Used to track number of functions available in this App')
var actionKeys = [
  'Send_an_email_V2'
]

//==============================================================================
// Resources
//==============================================================================

resource finopsAlerts 'Microsoft.Logic/workflows@2019-05-01' = {
  identity: {
    type: 'SystemAssigned'
  }
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
            frequency: recurrenceFrequency
            interval: recurrenceInterval
          }
          evaluatedRecurrence: {
            frequency: recurrenceFrequency
            interval: recurrenceInterval
          }
          type: recurrenceType
        }
      }
      actions: {
        For_each_App_GW: {
          foreach: '@body(\'Parse_idle_App_Gateways\')?[\'data\']'
          actions: {
            Set_App_Gateways_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'AppGwURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_App_GW\')?[\'tenantId\'],\'/resource\',items(\'For_each_App_GW\')?[\'id\'])}'
              }
            }
            Compose_AppGw: {
              runAfter: {
                Set_App_Gateways_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'AppGwURI\')'
            }
            Append_to_App_Gateway_HTML: {
              runAfter: {
                Compose_AppGw: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'AppGatewayHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_AppGw\')}">@{items(\'For_each_App_GW\')?[\'name\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_App_GW\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_AppGw\')}">@{items(\'For_each_App_GW\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_App_Gateway: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        For_each_Disk: {
          foreach: '@body(\'Parse_Idle_disks\')?[\'data\']'
          actions: {
            Set_Disk_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'DiskURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Disk\')?[\'tenantId\'],\'/resource\',items(\'For_each_Disk\')?[\'DiskId\'])}'
              }
            }
            Compose_Disk: {
              runAfter: {
                Set_Disk_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'DiskURI\')'
            }
            Append_to_Idle_Disk_HTML: {
              runAfter: {
                Compose_Disk: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'IdleDiskHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_Disk\')}">@{items(\'For_each_Disk\')?[\'DiskName\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_Disk\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_Disk\')}">@{items(\'For_each_Disk\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_Disk: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        For_each_IP_address: {
          foreach: '@body(\'Parse_Idle_IP_addresses\')?[\'data\']'
          actions: {
            Set_IP_address_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'IPAddressURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_IP_address\')?[\'tenantId\'],\'/resource\',items(\'For_each_IP_address\')?[\'PublicIpId\'])}'
              }
            }
            Compose_IP: {
              runAfter: {
                Set_IP_address_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'IPAddressURI\')'
            }
            Append_to_IP_Address_HTML: {
              runAfter: {
                Compose_IP: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'IPAddressHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_IP\')}">@{items(\'For_each_IP_address\')?[\'IPName\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_IP_address\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_IP\')}">@{items(\'For_each_IP_address\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_IP_Address: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        For_each_Load_Balancer: {
          foreach: '@body(\'Parse_Idle_Load_Balancers\')?[\'data\']'
          actions: {
            Set_Load_Balancer_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'LoadBalancerURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Load_Balancer\')?[\'tenantId\'],\'/resource\',items(\'For_each_Load_Balancer\')?[\'loadBalancerid\'])}'
              }
            }
            Compose_LB: {
              runAfter: {
                Set_Load_Balancer_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'LoadBalancerURI\')'
            }
            Append_to_Load_Balancer_HTML: {
              runAfter: {
                Compose_LB: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'LoadBalancerHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_LB\')}">@{items(\'For_each_Load_Balancer\')?[\'LoadBalancerName\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_Load_Balancer\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_LB\')}">@{items(\'For_each_Load_Balancer\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_Load_Balancer: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        For_each_Snapshot: {
          foreach: '@body(\'Parse_Snapshots\')?[\'data\']'
          actions: {
            Set_Snapshot_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'SnapshotURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Snapshot\')?[\'tenantId\'],\'/resource\',items(\'For_each_Snapshot\')?[\'SnapshotId\'])}\n'
              }
            }
            Compose_Snapshot: {
              runAfter: {
                Set_Snapshot_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'SnapshotURI\')'
            }
            Append_to_Disk_Snapshot_HTML: {
              runAfter: {
                Compose_Snapshot: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'DiskSnapshotHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_Snapshot\')}">@{items(\'For_each_Snapshot\')?[\'Snapshotname\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_Snapshot\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_Snapshot\')}">@{items(\'For_each_Snapshot\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_Disk_Snapshots: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        For_each_Stopped_VM: {
          foreach: '@body(\'Parse_stopped_VMs\')?[\'data\']'
          actions: {
            Set_Stopped_VM_URI: {
              type: 'SetVariable'
              inputs: {
                name: 'StoppedVMURI'
                value: '@{concat(\'https://portal.azure.com/#@\',items(\'For_each_Stopped_VM\')?[\'tenantId\'],\'/resource\',items(\'For_each_Stopped_VM\')?[\'VirtualMachineId\'])}'
              }
            }
            Compose_VM: {
              runAfter: {
                Set_Stopped_VM_URI: [
                  'Succeeded'
                ]
              }
              type: 'Compose'
              inputs: '@variables(\'StoppedVMURI\')'
            }
            Append_to_Stopped_VM_HTML: {
              runAfter: {
                Compose_VM: [
                  'Succeeded'
                ]
              }
              type: 'AppendToStringVariable'
              inputs: {
                name: 'StoppedVMHTML'
                value: '  <tr>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_VM\')}">@{items(\'For_each_Stopped_VM\')?[\'VMname\']}</a></td>\n    <td style="padding: 8px;">@{items(\'For_each_Stopped_VM\')?[\'resourceGroup\']}</td>\n    <td style="padding: 8px;"><a href="@{outputs(\'Compose_VM\')}">@{items(\'For_each_Stopped_VM\')?[\'subscriptionName\']}</a></td>\n  </tr>'
              }
            }
          }
          runAfter: {
            Condition_Stopped_VMs: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        Get_idle_App_Gateways: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'Microsoft.Network/applicationGateways\'| extend backendPoolsCount = array_length(properties.backendAddressPools),SKUName= tostring(properties.sku.name), SKUTier=tostring(properties.sku.tier),SKUCapacity=properties.sku.capacity,backendPools=properties.backendAddressPools|  join (resources | where type =~ \'Microsoft.Network/applicationGateways\'| mvexpand backendPools = properties.backendAddressPools| extend backendIPCount =array_length(backendPools.properties.backendIPConfigurations) | extend backendAddressesCount = array_length(backendPools.properties.backendAddresses) | extend backendPoolName=backendPools.properties.backendAddressPools.name | summarize backendIPCount = sum(backendIPCount) ,backendAddressesCount=sum(backendAddressesCount) by id) on id| project-away id1| where  (backendIPCount == 0 or isempty(backendIPCount)) and (backendAddressesCount==0 or isempty(backendAddressesCount))| order by id asc |  join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Get_idle_Disks: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'microsoft.compute/disks\' and managedBy == \'\'| extend diskState = tostring(properties.diskState) | where (managedBy == \'\' and diskState != \'ActiveSAS\') or (diskState == \'Unattached\' and diskState != \'ActiveSAS\') | extend DiskId = id, DiskName = name, SKUName = sku.name, SKUTier = sku.tier, DiskSizeGB = tostring(properties.diskSizeGB), Location = location, TimeCreated = tostring(properties.timeCreated) | order by DiskId asc | project DiskId, DiskName, DiskSizeGB, SKUName, SKUTier, resourceGroup, Location, TimeCreated, subscriptionId | join kind=leftouter (resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Get_idle_IP_addresses: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'Microsoft.Network/publicIPAddresses\' and isempty(properties.ipConfiguration) and isempty(properties.natGateway) | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, Location=location | project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, tenantId | union ( Resources | where type =~ \'microsoft.network/networkinterfaces\' and isempty(properties.virtualMachine) and isnull(properties.privateEndpoint) and isnotempty(properties.ipConfigurations) | extend IPconfig = properties.ipConfigurations | mv-expand IPconfig | extend PublicIpId= tostring(IPconfig.properties.publicIPAddress.id) | project PublicIpId | join (  resources | where type =~ \'Microsoft.Network/publicIPAddresses\' | extend PublicIpId=id, IPName=name, AllocationMethod=tostring(properties.publicIPAllocationMethod), SKUName=sku.name, resourceGroup, Location=location  ) on PublicIpId | project PublicIpId,IPName, SKUName, resourceGroup, Location, AllocationMethod, subscriptionId, tenantId) |  join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Get_idle_Load_Balancers: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'microsoft.network/loadbalancers\' and tostring(properties.backendAddressPools) == \'[]\' | extend loadBalancerId=id,LBRG=resourceGroup, LoadBalancerName=name, SKU=sku, LBLocation=location | order by loadBalancerId asc | project loadBalancerId,LoadBalancerName, SKU.name,SKU.tier, LBLocation, resourceGroup, subscriptionId |  join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Get_Disk_Snapshots_older_than_30_days: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'microsoft.compute/snapshots\' | extend TimeCreated = properties.timeCreated | where TimeCreated < ago(30d) | extend SnapshotId=id, Snapshotname=name | order by id asc | project id, SnapshotId, Snapshotname, resourceGroup, location, TimeCreated ,subscriptionId |  join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Get_Stopped_VMs: {
          runAfter: {
            Initialize_resources_table: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            uri: '${environment().resourceManager}//providers/Microsoft.ResourceGraph/resources?api-version=2021-03-01'
            method: 'POST'
            body: {
              query: '@{variables(\'resourcesTable\')} | where type =~ \'microsoft.compute/virtualmachines\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM deallocated\' and tostring(properties.extended.instanceView.powerState.displayStatus) != \'VM running\'| extend  VMname=name, PowerState=tostring(properties.extended.instanceView.powerState.displayStatus), VMLocation=location, VirtualMachineId=id| order by VirtualMachineId asc| project VirtualMachineId,VMname, PowerState, VMLocation, resourceGroup, subscriptionId |  join kind=leftouter ( resourcecontainers | where type == \'microsoft.resources/subscriptions\' | project subscriptionId, subscriptionName = name) on subscriptionId'
              scope: 'Tenant'
            }
            authentication: {
              type: 'ManagedServiceIdentity'
            }
          }
        }
        Initialize_App_Gateways_URI: {
          runAfter: {
            Parse_idle_App_Gateways: [
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
        Initialize_Disk_URI: {
          runAfter: {
            Parse_Idle_disks: [
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
        Initialize_IP_addresses_URI: {
          runAfter: {
            Parse_Idle_IP_addresses: [
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
        Initialize_Load_Balancer_URI: {
          runAfter: {
            Parse_Idle_Load_Balancers: [
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
        Initialize_Snapshot_URI: {
          runAfter: {
            Parse_Snapshots: [
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
        Initialize_Stopped_VM_URI: {
          runAfter: {
            Parse_stopped_VMs: [
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
        Excluded_subscriptions: {
          runAfter: {
            Included_subscriptions: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'ExcludedSubscriptions'
                type: 'array'
                value: []
              }
            ]
          }
        }
        Parse_idle_App_Gateways: {
          runAfter: {
            Get_idle_App_Gateways: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_idle_App_Gateways\')'
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
            Get_idle_IP_addresses: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_idle_IP_addresses\')'
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
            Get_idle_Load_Balancers: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_idle_Load_Balancers\')'
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
            Get_idle_Disks: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Get_idle_Disks\')'
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
        Parse_stopped_VMs: {
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
        Set_alert_recipient: {
          runAfter: {
            Set_email_subject: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SendAlertTo'
                type: 'string'
              }
            ]
          }
        }
        Initialize_App_Gateway_HTML: {
          runAfter: {
            Initialize_App_Gateways_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'AppGatewayHTML'
                type: 'string'
                value: '<h2>Idle Application Gateway Details</h2>'
              }
            ]
          }
        }
        Initialize_Disk_HTML: {
          runAfter: {
            Initialize_Disk_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'IdleDiskHTML'
                type: 'string'
                value: '<h2>Idle Disk Details</h2>'
              }
            ]
          }
        }
        'Send_an_email_(V2)': {
          runAfter: {
            EmailNotice: [
              'Succeeded'
            ]
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'office365\'][\'connectionId\']'
              }
            }
            method: 'post'
            body: {
              To: '@variables(\'SendAlertTo\')'
              Subject: '@variables(\'SetEmailSubject\')'
              Body: '<p class="editor-paragraph">@{variables(\'EmailNotice\')}</p><p class="editor-paragraph">@{variables(\'AppGatewayHTML\')}<br>@{variables(\'IdleDiskHTML\')}<br>@{variables(\'IPAddressHTML\')}<br>@{variables(\'LoadBalancerHTML\')}<br>@{variables(\'DiskSnapshotHTML\')}<br>@{variables(\'StoppedVMHTML\')}</p><br><h1 class="editor-heading-h1"><b><strong class="editor-text-bold">📧 </strong></b><b><strong class="editor-text-bold" style="font-size: 20px;">About FinOps alerts</strong></b></h1><p class="editor-paragraph">FinOps alerts keep you informed about cost optimization opportunities within in your cloud environment. They are fully configurable and can be tailored to run on your desired schedule, ensuring that you receive timely notifications on the scenarios most important to your organization. FinOps alerts are part of the FinOps toolkit, an open-source collection of FinOps solutions that help you manage and optimize your cost, usage, and carbon.</p><h1 class="editor-heading-h1"><b><strong class="editor-text-bold" style="font-size: 20px;">Provide feedback</strong></b></h1><p class="editor-paragraph"><a href="https://portal.azure.com/#view/HubsExtension/InProductFeedbackBlade/extensionName/FinOpsToolkit/cesQuestion/How%20easy%20or%20hard%20is%20it%20to%20use%20FinOps%20alerts%3F/cvaQuestion/How%20valuable%20are%20FinOps%20alerts%3F/surveyId/FTK0.9/bladeName/Alerts/featureName/Email" class="editor-link"><u><span class="editor-text-underline">Give feedback</span></u></a><br><a href="https://github.com/microsoft/finops-toolkit/issues?q=is%3Aissue%20is%3Aopen%20label%3A%22Tool%3A%20FinOps%20alerts%22%20sort%3Areactions-%2B1-desc" class="editor-link"><u><span class="editor-text-underline">Vote on or suggest ideas</span></u></a></p><br>'
            }
            path: '/v2/Mail'
          }
        }
        Initialize_IP_Address_HTML: {
          runAfter: {
            Initialize_IP_addresses_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'IPAddressHTML'
                type: 'string'
                value: '<h2>Idle IP Address Details</h2>'
              }
            ]
          }
        }
        Initialize_Load_Balancer_HTML: {
          runAfter: {
            Initialize_Load_Balancer_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'LoadBalancerHTML'
                type: 'string'
                value: '<h2>Idle Load Balancer Details</h2>'
              }
            ]
          }
        }
        Initialize_Disk_Snapshot_HTML: {
          runAfter: {
            Initialize_Snapshot_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'DiskSnapshotHTML'
                type: 'string'
                value: '<h2>Old Disk Snapshot Details</h2>'
              }
            ]
          }
        }
        Initialize_Stopped_VM_HTML: {
          runAfter: {
            Initialize_Stopped_VM_URI: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'StoppedVMHTML'
                type: 'string'
                value: '<h2>Stopped VM Details</h2>'
              }
            ]
          }
        }
        End_to_App_Gateway_HTML: {
          runAfter: {
            For_each_App_GW: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'AppGatewayHTML'
            value: '</tbody></table>'
          }
        }
        End_to_IP_Address_HTML: {
          runAfter: {
            For_each_IP_address: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'IPAddressHTML'
            value: ' </table>'
          }
        }
        End_to_Disk_HTML: {
          runAfter: {
            For_each_Disk: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'IdleDiskHTML'
            value: '</tbody></table>'
          }
        }
        End_to_Load_Balancer_HTML: {
          runAfter: {
            For_each_Load_Balancer: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'LoadBalancerHTML'
            value: '</table>'
          }
        }
        End_to_Disk_Snapshot_HTML: {
          runAfter: {
            For_each_Snapshot: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'DiskSnapshotHTML'
            value: '</table>'
          }
        }
        End_to_Stopped_VM_HTML: {
          runAfter: {
            For_each_Stopped_VM: [
              'Succeeded'
            ]
          }
          type: 'AppendToStringVariable'
          inputs: {
            name: 'StoppedVMHTML'
            value: '</table>'
          }
        }
        Set_email_subject: {
          runAfter: {}
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'SetEmailSubject'
                type: 'string'
              }
            ]
          }
        }
        Included_subscriptions: {
          runAfter: {
            Set_alert_recipient: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'IncludedSubscriptions'
                type: 'array'
                value: []
              }
            ]
          }
        }
        Initialize_resources_table: {
          runAfter: {
            Excluded_subscriptions: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'resourcesTable'
                type: 'string'
                value: 'resources@{if(equals(length(variables(\'IncludedSubscriptions\')), 0), \'\', concat(\'| where subscriptionId in ("\', replace(replace(string(variables(\'IncludedSubscriptions\')), \'[\', \'\'), \']\', \'\'), \'")\'))}@{if(equals(length(variables(\'ExcludedSubscriptions\')), 0), \'\', concat(\'| where subscriptionId !in ("\', replace(replace(string(variables(\'ExcludedSubscriptions\')), \'[\', \'\'), \']\', \'\'), \'")\'))}'
              }
            ]
          }
        }
        Condition_App_Gateway: {
          actions: {
            Append_no_App_Gateway_results_text: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'AppGatewayHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_App_Gateway_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_App_Gateway_results_in_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'AppGatewayHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_App_Gateways\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Stopped_VMs: {
          actions: {
            Append_no_Stopped_VM_results_text_: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'StoppedVMHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_Stopped_VM_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_Stopped_VM_result_in_table_: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'StoppedVMHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_Stopped_VMs\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Disk: {
          actions: {
            Append_no_Disk_results_text: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'IdleDiskHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_Disk_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_Disk_results_in_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'IdleDiskHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_Disks\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_IP_Address: {
          actions: {
            Append_no_IP_Address_results_text: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'IPAddressHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_IP_Address_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_IP_Address_results_in_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'IPAddressHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_IP_addresses\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Load_Balancer: {
          actions: {
            Append_no_Load_Balancer_results_text: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'LoadBalancerHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_Load_Balancer_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_Load_Balancer_results_in_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'LoadBalancerHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_Load_Balancers\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Disk_Snapshots: {
          actions: {
            Append_no_Disk_Snapshot_results_text: {
              type: 'AppendToStringVariable'
              inputs: {
                name: 'DiskSnapshotHTML'
                value: 'No resources are idle.'
              }
            }
          }
          runAfter: {
            Initialize_Disk_Snapshot_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_Disk_Snapshot_results_in_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'DiskSnapshotHTML'
                  value: '<table border="1" style="border-collapse: collapse;">\n  <thead><tr>\n    <th style="padding: 8px;">Name</th>\n    <th style="padding: 8px;">Resource Group</th>\n    <th style="padding: 8px;">Subscription</th>\n  </tr></thead>\n<tbody>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_Disk_Snapshots_older_than_30_days\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_App_Gateway_next_steps: {
          actions: {}
          runAfter: {
            End_to_App_Gateway_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_App_Gateway_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'AppGatewayHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong> <span>Review application gateways which include backend pools with no targets.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_App_Gateways\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Disk_next_steps: {
          actions: {}
          runAfter: {
            End_to_Disk_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_Disk_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'IdleDiskHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong> <span>Review managed disks that are not attached to any virtual machine.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_Disks\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_IP_Address_next_steps: {
          actions: {}
          runAfter: {
            End_to_IP_Address_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_IP_Address_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'IPAddressHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong> <span>Review unattached public IP addresses, as they may represent additional cost.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_IP_addresses\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Load_Balancer_next_steps: {
          actions: {}
          runAfter: {
            End_to_Load_Balancer_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_Load_Balancer_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'LoadBalancerHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong> <span>Review load balancers with no backend pools and remove them if not needed.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_idle_Load_Balancers\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_Disk_Snapshot_next_steps: {
          actions: {}
          runAfter: {
            End_to_Disk_Snapshot_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_Disk_Snapshot_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'DiskSnapshotHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong> <span>Review managed disk snapshots that are older than 30 days.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_Disk_Snapshots_older_than_30_days\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        Condition_stopped_VM_next_steps: {
          actions: {}
          runAfter: {
            End_to_Stopped_VM_HTML: [
              'Succeeded'
            ]
          }
          else: {
            actions: {
              Append_to_Stopped_VM_table: {
                type: 'AppendToStringVariable'
                inputs: {
                  name: 'StoppedVMHTML'
                  value: '<div style="margin-top: 16px;">\n  <strong>👉 Next steps:</strong>  <span>Review stopped VMs, as they are billed for the allocated cost.</span>\n</div>'
                }
              }
            }
          }
          expression: {
            and: [
              {
                equals: [
                  '@length(body(\'Get_Stopped_VMs\')[\'data\'])'
                  0
                ]
              }
            ]
          }
          type: 'If'
        }
        EmailNotice: {
          runAfter: {
            Condition_App_Gateway_next_steps: [
              'Succeeded'
            ]
            Condition_Disk_next_steps: [
              'Succeeded'
            ]
            Condition_IP_Address_next_steps: [
              'Succeeded'
            ]
            Condition_Load_Balancer_next_steps: [
              'Succeeded'
            ]
            Condition_Disk_Snapshot_next_steps: [
              'Succeeded'
            ]
            Condition_stopped_VM_next_steps: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'EmailNotice'
                type: 'string'
                value: '<p class="editor-paragraph"><b><strong class="editor-text-bold">The following resources have been identified through FinOps alerts. </strong></b><b><strong class="editor-text-bold">Please take a moment to review and proceed with the next steps outlined below:</strong></b></p><hr><br>'
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
            connectionId: apiConnection.id
            connectionName: connectionName
            id: resourceId('Microsoft.Web/locations/managedApis', location, 'office365')
          }
        }
      }
    }
  }
  name: appName
  location: location
  tags: {
    displayName: 'FinOpsalert'
  }
}

resource apiConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: connectionName
  location: location
  properties: {
    api: {
      id: resourceId('Microsoft.Web/locations/managedApis', location, 'office365')
    }
    displayName:displayName
  }
}

//==============================================================================
// Outputs
//==============================================================================
output logicAppName string = finopsAlerts.name
output connectionName string = connectionName
output actionsCount int = length(actionKeys)
output logicAppResourceId string = finopsAlerts.id
output logicAppPrincipalId string = finopsAlerts.identity.principalId
output logicAppTriggerUrl string = 'https://${finopsAlerts.name}.logic.azure.com:443/workflows/${finopsAlerts.name}/triggers/Recurrence/run?api-version=2016-10-01'
