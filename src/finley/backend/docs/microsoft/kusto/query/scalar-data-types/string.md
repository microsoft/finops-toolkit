# string data type

Applies to: ✅ Microsoft Fabric ✅ Azure Data Explorer ✅ Azure Monitor ✅ Microsoft Sentinel

The `string` data type represents a sequence of zero or more Unicode characters.

## String literals

There are several ways to encode literals of the `string` data type.

* Enclose the string in double quotes (`"`): `"This is a string literal"`
* Enclose the string in single quotes (`'`): `'This is a string literal'`

> [!NOTE]
> There is no difference between single-quoted strings and double-quoted strings in Kusto.

### Escape sequences

Both single-quoted and double-quoted strings support the same escape sequences:

|Escape sequence|Description|
|--|--|
|`\\`|Backslash character (\\)|
|`\'`|Single quote character (')|
|`\"`|Double quote character (")|
|`\a`|ASCII bell (alert) character|
|`\b`|ASCII backspace character|
|`\f`|ASCII form feed character|
|`\n`|ASCII line feed character|
|`\r`|ASCII carriage return character|
|`\t`|ASCII tab character|
|`\v`|ASCII vertical tab character|
|`\xNN`|ASCII/Extended ASCII character specified by a two-digit hex code|
|`\uNNNN`|Unicode character specified by a four-digit hex code|
|`\UNNNNNNNN`|Unicode character specified by an eight-digit hex code|

## Examples

```kusto
print text = 'This is a "double quoted" string literal'
```

```kusto
print text = "This is a 'single quoted' string literal"
```

```kusto
print text = @"This is a ""verbatim"" string literal \no escape sequences\."
```

## Operators and functions

The `string` data type supports the following operators and functions:

### Operators

* `==`, `!=` (comparison)
* `!~`, `has`, `contains`, `startswith`, `endswith`, `matches regex` (text search)
* `+` (concatenation)

### Functions

Kusto provides a rich set of string manipulation functions. Here are some examples:

* [`countof()`](../functions/countof-function.md): Counts occurrences of a substring in a string
* [`extract()`](../functions/extract-function.md): Get a match for a regular expression
* [`isempty()`](../functions/isempty-function.md): Checks if a string is empty
* [`replace()`](../functions/replace-function.md): Replace all occurrences of a string with another string
* [`split()`](../functions/split-function.md): Splits a string according to a delimiter
* [`strcat()`](../functions/strcat-function.md): Concatenates between 1 and 64 arguments
* [`strlen()`](../functions/strlen-function.md): Returns the length of a string
* [`substring()`](../functions/substring-function.md): Extracts a substring from a source string starting from some index
* [`tolower()`](../functions/tolower-function.md): Converts a string to lowercase
* [`toupper()`](../functions/toupper-function.md): Converts a string to uppercase
* [`trim()`](../functions/trim-function.md): Removes all leading and trailing whitespace from a string
