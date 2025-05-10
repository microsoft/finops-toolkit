# Prompt engineering techniques

## Best practices

- Be Specific. Leave as little to interpretation as possible. Restrict the operational space.
- Be Descriptive. Use analogies.
- Double Down. Sometimes you might need to repeat yourself to the model. Give instructions before and after your primary content, use an instruction and a cue, etc.
- Order Matters. The order in which you present information to the model might impact the output. Whether you put instructions before your content ("summarize the following…") or after ("summarize the above…") can make a difference in output. Even the order of few-shot examples can matter. This is referred to as recency bias.
- Give the model an "out". It can sometimes be helpful to give the model an alternative path if it is unable to complete the assigned task. For example, when asking a question over a piece of text you might include something like "respond with "not found" if the answer is not present." This can help the model avoid generating false responses.

...
