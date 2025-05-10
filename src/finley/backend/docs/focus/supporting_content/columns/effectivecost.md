# Column: Effective Cost

## Example Scenarios

### 7 Day Full upfront Reservation

#### On the day of purchase a row exists for the upfront cost of the reservation as follows

| Charge period           | Billing period           | Charge Category | Units | Billed Cost | Effective Cost |
| ----------------------- | ------------------------ | ----------- | ----- | ----------- | -------------- |
| Jan 1 2023 - Jan 1 2024 | Jan 1 2023 - Jan 31 2023 | Purchase    | 3     | 26.69589041 | 0              |

*Note: Billed cost is showing the total cash outlay for the reservation. Also note there is no initial Reserved Instance fee representing the cost of the RI for the applicable period.*

___

#### Also on each hour a row is added as follows

| Charge period           | Billing period           | Charge Category | Units | Billed Cost | Effective Cost |
| ----------------------- | ------------------------ | ----------- | ----- | ----------- | -------------- |
| Jan 1 2023 - Jan 2 2023 | Jan 1 2023 - Jan 31 2023 | Usage       | 3     | 0           | 3.81369863     |

*Note: The amortization is equal to the (Upfront fee / (number of normalized units reserved x periods) x normalized units consumed).*

___

#### If the Reserved Instance is unused during a period, for example another ineligible instance type is used

| Charge period           | Billing period           | Charge Category     | Units | Billed Cost | Effective Cost |
| ----------------------- | ------------------------ | --------------- | ----- | ----------- | -------------- |
| Jan 4 2023 - Jan 5 2023 | Jan 1 2023 - Jan 31 2023 | OD Usag         | 3     | 5.544       | 5.544          |
| Jan 4 2023 - Jan 5 2023 | Jan 1 2023 - Jan 31 2023 | Unused RI Usage | 3     | 0           | 3.81369863     |

*Note: For the On Demand usage the Billed cost and Effective cost are the same with an Amortization of Zero. Since the RI went completely unused during the period there is an unused RI usage row with the an amortization equal to (Upfront fee / (number of normalized units reserved x periods) x normalized units.*

___

#### If the RI is partially unused during a period, for example a scale down occurs

| Charge period           | Billing period           | Charge Category     | Units | Billed Cost | Effective Cost |
| ----------------------- | ------------------------ | --------------- | ----- | ----------- | -------------- |
| Jan 4 2023 - Jan 5 2023 | Jan 1 2023 - Jan 31 2023 | OD Usage        | 1     | 0           | 2.542465753          |
| Jan 4 2023 - Jan 5 2023 | Jan 1 2023 - Jan 31 2023 | Unused RI Usage | 2     | 0           | 1.271232877     |

*Note: For the Reserved Instance Usage the Billed cost is zero as this RI is full upfront. It is especially important to note that the usage units must be normalized for this formula to be applicable in cases of commitment discount flexibility (e.g. c7g.large normalized units is 4, c7g.medium is 2). Effective cost is the same as amortization because the upfront fee covers all of the compute usage expense for this row.*

### Example usage scenarios

See [Cost Metrics Examples Spreadsheet](https://docs.google.com/spreadsheets/d/1bhRELDgf3LTSfQJRrCyovTt65g4ElimYHq6fmKOz83E) for examples of billing data for various scenarios.
