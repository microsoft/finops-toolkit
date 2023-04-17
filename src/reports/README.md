# 📊 FinOps toolkit reports

FinOps toolkit reports are created and edited using [Power BI Desktop](https://powerbi.microsoft.com/desktop). We currently support the following reports:

- [Cost summary](./CostSummary.pbix)
- [Commitment discounts](./CommitmentDiscounts.pbix)

---

## 🔠 Changing schema

FinOps toolkit reports maintain different queries for each schema version to avoid breaking old reports during an upgrade. Use the following steps when changing the schema:

1. Open the desired toolkit report in Power BI Desktop.
2. Select **Transform data** in the toolbar.
3. Either create a new query with **Get data** or right-click the latest query and select **Duplicate**, if the data source is not changing.
   - Customize the new query as desired.
   - If creating a new query, make sure to account for any customizations in the old latest (previous) query.
   - Use the advanced editor to add comments for future maintainability.
   - Set the name to `NEW_<new-query-name>`, replacing the placeholder with a name that clearly indicates the new schema version.
4. Rename the old latest query to `PREV_<previous-query-name>` and change the query to reference the NEW query and undo any changes:

   1. Replace the query text with the following using the advanced editor:

      ```powerquery <!-- spell-checker:disable-line -->
      let
          // Schema mapping from <new-query-name> to <previous-query-name>
          Source = NEW_<new-query-name>,

          // TODO: Mapping to old schema goes here...
      in
          Source
      ```

   2. Replace the `<previous-query-name>` placeholder.
   3. Replace the `<new-query-name>` placeholder with the same value in step 3.
   4. Customize this query to undo all changes from step 3 so the data looks _**exactly**_ like it did before.
      > ⚠️ _This is the most critical step. The old data must stay exactly the same to ensure back-compat._

5. Select **Close & Apply** in the toolbar.
   > ℹ️ _At this point, you have a new query that isn't used and all visuals are still pointing at the old query. We're doing this to validate back-compat of the old query._
6. Validate all pages to ensure visuals, custom columns, and measures are rendering correctly with no errors.
   - Any errors will have been caused because something wasn't mapped back to the original schema in step 3.
   - Update as needed.
7. After all issues are resolved, duplicate the validated PREV query from step 4 and name the duplicate query `<previous-query-name>` (same as what it originally was).
8. Copy the TEMP query text using the advanced editor.
9. Update the PREV query text with the copied query and rename it to `<new-query-name>` (same as steps 3-4).
10. Delete the NEW query (since this has now replaced the previous query).
11. Select **Close & Apply** in the toolbar.
    > ℹ️ _At this point, your new query should be linked to all visuals._
12. Validate all pages to ensure visuals, custom columns, and measures are rendering correctly with no errors.
    - Note you may need to update columns and measures depending on the dataset changes.
    - Validate columns and measures first and update as needed.
    - Then validate visuals and update all as needed.
13. Document the new dataset in [Queries and datasets](../../docs/reports/README.md#queries-and-datasets).
14. Update the references to the latest dataset name in the following places:
    - [Copy queries from a toolkit report](../../docs/reports/README.md#copy-queries-from-a-toolkit-report)
    - [Queries and datasets](../../docs/reports/README.md#queries-and-datasets)
15. If appropriate, document the new dataset in the [changelog](../../docs/changelog.md).
16. Repeat these steps for each toolkit report:

    1. Rename the old query to `<new-query-name>` and copy the text from the first report.
    2. Create a new blank query named `<previous-query-name>` and copy the text from the first report.
    3. Update any queries that referenced the old query. Note the reference will have changed to the new query name, so you'll need to change them back to the previous name.
    4. Validate all pages to ensure visuals, custom columns, and measures are rendering correctly with no errors and update as needed. You will need to repeat similar updates as step 12.
