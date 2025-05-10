# Prompt engineering techniques

## Scenario-specific guidance

While the principles of prompt engineering can be generalized across many different model types, certain models expect a specialized prompt structure. For Azure OpenAI GPT models, there are currently two distinct APIs where prompt engineering comes into play:

- Chat Completion API.
- Completion API.

Each API requires input data to be formatted differently, which in turn impacts overall prompt design. The Chat Completion API supports the GPT-35-Turbo and GPT-4 models. These models are designed to take input formatted in a specific chat-like transcript stored inside an array of dictionaries.

The Completion API supports the older GPT-3 models and has much more flexible input requirements in that it takes a string of text with no specific format rules.

...
