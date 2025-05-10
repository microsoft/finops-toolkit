# Scheme Creation Scenarios

## The following is a list of scenarios and their schema update requirements


| Scenario                                                                                                 | Requires New Schema object	 | Requires Change in Provider Version | 	Requires Change FOCUS Version |
|:---------------------------------------------------------------------------------------------------------|:----------------------------|:------------------------------------|:-------------------------------|
| Provider uses a new focus version when they supply a provider version	                                   | Y                           |                                     | Y                              |N |
| Provider is changing the way they generate the data that doesn't affect the focus version or the columns | 	Y	                         | Y                                   | 	N                             |
| Addition of Column | 	Y	                         | N                                   | 	N                             |
| Removal of Columns	| Y	                          | N	                          | N                                   |
| Change of Focus Version	| Y                           | 	Y| 	Y|
| Correction of schema metadata that is not correct | 	N                          | 	N                                  | 	N                             |