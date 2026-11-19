# Developer content, and chatbots and virtual agents

## Developer content

Though the content for developers and IT professionals tends to be more technical than that for a general audience, the fundamentals of the Microsoft brand voice still apply. Be warm and relaxed, crisp and clear, and ready to lend a hand as appropriate for the context. After all, when they're not coding or managing solutions, developers and IT pros are some of the very same people who play Xbox and use Office.

Of course, it's OK to assume IT pros and developers bring a fundamental understanding of programming concepts. So skip the basic knowledge and focus on technology-specific or product-specific information that helps them achieve their goals.

Two types of content form the foundation of developer documentation: reference documentation and code examples. Reference documentation provides an encyclopedia of all the programming elements, such as classes, methods, and properties, that are available for writing applications. Code examples show how to use those elements.

This section provides guidelines for creating:

  - Reference documentation
  - Code examples

It also has guidelines for formatting developer text elements.

## Reference documentation

Reference documentation provides details about the programming elements associated with technologies and languages, including class libraries, object models, and programming language constructs.

Consistency is essential in reference documentation. A standard article design, predictable headings and structure, and consistent wording help developers find what they need quickly. Links to articles with related information are also a common feature.

**Note** Information such as configuration schemas, compiler options, and error messages might not follow the guidelines described in this section.

## Article titles

Use the name of a programming element (such as Clear), followed by an element type (such as Class, Method, Property, or Event). If the name is shared by multiple elements, add a differentiator, such as the parent element name or the product or technology name. Differentiators are particularly important in search results, where they help customers find the article for the correct product or element.

**Examples** Clear method Device.Clear method Clear method (ADO)

## Elements of a reference article

The table lists the information typically provided in reference articles. Not all sections appear in all reference articles. Sections vary depending on the language, product, or technology being documented.

|        **Section**         |                                                                                                                                                                                                                                                                   **Contains**                                                                                                                                                                                                                                                                    |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|      **Title and description**       |                                                                                                                            The name of the element and a concise sentence or two describing the element. If possible, explain what the element does or represents without repeating the element name.<br />**Example**<br />MoveRecord method (ADO)<br />Moves the entity represented by a **Record** to another location.                                                                                                                              |
|   **Declaration/syntax**   |                                                                                                                                                                          The code signature that defines the element. This section might also provide usage syntax. If the technology can be used with multiple programming languages, provide syntax for each language. <br />**Example**<br />`Record.MoveRecord (Source, Destination, UserName, Password, Options, Async)`                                                                                               |
|       **Parameters**       | If the element has parameters, provide a description of each parameter and its data type. If appropriate, indicate whether the parameter is required or optional and whether it represents input or output. Provide as much useful detail as possible. Don't just repeat the words in the parameter name or the data type.<br />**Examples**<br />*Source*<br />Optional. A **String** value that contains a URL identifying the **Record** to be moved. If *Source* is omitted or specifies an empty string, the object represented by this **Record** is moved. For example, if the **Record** represents a file, the contents of the file are moved to the location specified by *Destination.*<br /><br />*Destination*<br />Optional. A **String** value that contains a URL specifying the location where *Source* will be moved.<br /><br />*UserName*<br />Optional. A **String** value that contains the user ID that, if needed, authorizes access to *Destination.*<br /><br />*Password*<br />Optional. A **String** that contains the password that, if needed, verifies *UserName.*<br /><br />*Options*<br />Optional. A **MoveRecordOptionsEnum** value whose default value is **adMoveUnspecified**. Specifies the behavior of this method.<br /><br />*Async*<br />Optional. A **Boolean** value that, when **True**, specifies this operation should be asynchronous.                                                             |
|      **Return value**      |                                                                                                                                                                               If the element returns a value, describe the value and information about its data type. If the value is a Boolean that indicates the presence of a condition, describe the condition. <br />**Example**<br />A **String** value. Typically, the value of *Destination* is returned. However, the exact value returned is provider-dependent.                                                                                                                                                                              |
|        **Remarks**         |                                                                                                                               Additional information about the element and important details that may not be obvious from its syntax, parameters, or return value. For example, you might explain what the element does in more detail, compare it with similar elements, and identify potential issues in its use. <br />**Example**<br />The values of *Source* and *Destination* must not be identical; otherwise, a runtime error occurs. At least the server, path, and resource names must differ.<br /><br />For files moved using the Internet Publishing Provider, this method updates all hypertext links in files being moved unless otherwise specified by *Options.* This method fails if *Destination* identifies an existing object (for example, a file or directory), unless **adMoveOverWrite** is specified.<br /><br />**Note** Use the **adMoveOverWrite** option judiciously. For example, specifying this option when moving a file to a directory will delete the directory and replace it with the file.<br /><br />Certain attributes of the **Record** object, such as the **ParentURL** property, won't be updated after this operation completes. Refresh the **Record** object's properties by closing the **Record**, then reopening it with the URL of the location where the file or directory was moved.<br /><br />If this **Record** was obtained from a **Recordset**, the new location of the moved file or directory won't be reflected immediately in the **Recordset**. Refresh the **Recordset** by closing and reopening it.<br /><br />**Note** URLs using the http scheme will automatically invoke the Microsoft OLE DB Provider for Internet Publishing. For more information, see Absolute and Relative URLs.                                                                                                                              |
|        **Example**         |                                                                                                                                                                                       A code example that illustrates how to use the programming element. For more information about writing useful code examples, see Code examples.                                                                                                                                                                                       |
|      **Requirements or Applies to**      |                                                                                                                                                                                                                                             Language or platform requirements for using the element.<br />**Example**<br />Record Object (ADO)                                                                                          |
|        **See also**        |                                                                                                                                                     References or links to more information about how to use the element. References or links to related elements.<br />**Examples**<br />Move Method (ADO)<br />MoveFirst, MoveLast, MoveNext, and MovePrevious Methods (ADO) <br />MoveFirst, MoveLast, MoveNext, and MovePrevious Methods (RDS)                                                                                                                                    |

Other information can appear in reference articles as appropriate to the language, product, or technology. For example, instead of a parameter description as shown in the preceding table, there can be descriptions of members, methods, property values, and field values. The following table contains an example of a property value and examples of exceptions and permissions.

|        **Section**         |                                                                                                                                                                                                                                                                   **Contains**                                                                                                                                                                                                                                                                    |
|----------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
|  **Property value**  |                                                                                                                                                                           A description of the value for a property or field. If the property or field has a default value, describe that, too. Include the data type of the property value if applicable.<br />**Example<br />Property Value**<br />String<br />Returns or sets a String value representing the current date according to your system.                                                                         |
| **Exceptions/error codes** |                                                                                                                                                                                                          If the element can throw exceptions or raise errors when called, list them and describe the conditions under which they occur.<br />**Example**<br />IOException—An I/O error occurred.<br />ArgumentNullException—*format* is null.<br />FormatException—The format specification in *format* is invalid.                                                |
|      **Permissions**       |                                                                                                                                                                                                                                           Security permissions that apply to the element, if required.<br />**Example**<br />Requires CREATE FUNCTION permission in the database and ALTER permission on the schema in which the function is being created. If the function specifies a user-defined type, requires EXECUTE permission on the type.                                                                                                                                                     |

If you automatically generate reference documentation and comments from the source code, review the quality and appropriateness of the comments. Developers might leave out details that are important to customers. Remove any implementation or internal details that aren't suitable for documentation.

**Learn more** For other examples of technical reference articles, see the .NET API Browser.

## Code examples

Code examples illustrate how to use a programming element to implement specific functionality. They might include:

  - Simple, one-line examples interspersed with text.
  - Short, self-contained examples that illustrate specific points.
  - Long samples that illustrate multiple features, complex scenarios, or best practices. 

Developers use code examples to:

  - Assess a technology through its API during planning.
  - Learn or explore a language or technology.
  - Write and debug code.

Many developers copy example code from documentation into their own code or adapt code examples to their own needs.

To create useful code examples, identify tasks and scenarios that are meaningful for your audience, and then create examples that illustrate those scenarios. Code examples that demonstrate product features are useful only when they address the problems that developers are trying to solve.

**Guidelines for planning code examples**

- Create concise examples that exemplify key development tasks. Start with simple examples and build up complexity after you cover common scenarios. 

- Prioritize frequently used elements and elements that may be difficult to understand or tricky to use. 

- Don't use code examples to illustrate obvious points or contrived scenarios. 

- Create code examples that are easy to scan and understand. Reserve complicated examples for tutorials and walkthroughs, where you can provide a step-by-step explanation of how the example works.

- Add an introduction to describe the scenario and explain anything that might not be clear from the code. List the requirements and dependencies for using or running the example.

- Provide an easy way for developers to copy and run the code. If the code example demonstrates interactive and animated features, consider providing a way for the developer to run the example directly from your content page.

- Use appropriate keywords, linking strategies, and other search engine optimization (SEO) techniques to improve the visibility and usability of the code examples. For example, add links to relevant code example pages and content pages to improve SEO across your content. See Search and writing. 

**Guidelines for writing code examples**

- Design code for reuse. Help developers determine what to modify. Add comments to explain details, but don't overdo it. Don't state the obvious.

- Show expected output, either in a separate section after the code example or by using code comments within the code example. 

- Consider accessibility requirements for code that creates UI. For example, include alternate text for images. 

- Write secure code. For example, always validate user input, never hard-code passwords in code, and use code-analysis tools to detect security issues. 

- Show exception handling only when it's intrinsic to the example. Don't catch exceptions thrown when invalid arguments are passed to parameters. 

- Always compile and test your code.

## Formatting developer text elements

Consistent text formatting helps readers locate and interpret information. Follow these formatting conventions for text elements that are commonly used in content for developers.

In general, use code style for programmatic or code-related elements. The following table lists examples of common programming elements, and some exceptions to the code style convention. Consider localization needs for the text elements that you're formatting.

The capitalization of developer text elements varies depending on the programming language or operating environment. When you're documenting code, capitalization should follow what the code uses.

**See also** Capitalization Formatting common text elements Formatting text in instructions Procedures and instructions

|                                                               **Element**                                                                |                                                                                                                    **Convention**                                                                                                                    |                                                                                                                          **Example**                                                                                                                           |
|------------------------------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **AI prompts** | Quotation marks, if you're referencing prompts in text. <br /><br />If prompts appear in a list and the introductory text makes clear what those items are, special formatting isn't necessary. | "List all of my subscriptions."
|                                                              **Attributes**                                                              |                                                                                                             Code style.                                                                                                             |                                                                                                                     `IfOutputPrecision`                                                                                                                      |
|                                                         **Classes (predefined or user-defined)**                                                         |                                                                                                             Code style.                                                                                                             |                                                                                                           `ios`<br />`filebuf`<br />`BitArray`<br /> `BlueTimerControl`                                                                                                           |
| **Code samples, including keywords and variables within text and as separate paragraphs, and user-defined program elements within text** |                                                                                                                      Code style.                                                                                                                      |                                                                                                              `#include <iostream.h>` <br /> `void main ()`                                                                                                               |
|                                                        **Command-line commands**                                                         |                                                                                                                 Code style.                                                                                                                |                                                                                                                            `copy`                                                                                                                            |
|                                        **Command-line options (also known as switches or flags)**                                        |                                                                                                  Code style. Capitalize the way the option must be typed.                                                                                                  |                                                                                                                      `/a`<br />`/Aw`                                                                                                                       |
|                                                              **Constants**                                                               |                                                                                                         Code style.                                                                                                         |                                                                                                          `INT_MAX`<br />`bDenyWrite`<br />`CS_DBLCLKS`                                                                                                           |
|                                                           **Control classes**                                                            |                                                                                                                   Code style. All uppercase.                                                                                                                    |                                                                                                                       `EDIT` control class                                                                                                                       |
|                                                             **Data formats**                                                             |                                                                                                                    Code style. All uppercase.                                                                                                                    |                                                                                                                             `CF_DIB` format                                                                                                                             |
|                                            **Data structures and their members (predefined)**                                            |                                                                                                             Code style.                                                                                                             |                                                                                              `BITMAP`<br />`bmBits`<br />`CREATESTRUCT`<br />`hInstance`                                                                                               |
|                                                              **Data types**                                                              |                                                                                                    Code style. Capitalization follows the API.                                                                                                     |                                                                                                            `DWORD`<br />`float`<br />`HANDLE`                                                                                                            |
|                                                            **Database names**                                                            |                                                                                                  Bold. Code style if using in code syntax.                                                                                                  |                                                                                                                      **Contoso** database<br />`USE ContosoSalesDatabase;`                                                                                                                      |
|                                                              **Directives**                                                              |                                                                                                                        Code style.                                                                                                                         |                                                                                                                `\#include`<br />`\#define`                                                                                                                 |
|                                                        **Environment variables**                                                         |                                                                                                                    Code style.                                                                                                                    |                                                                                                                  `INCLUDE`<br />`SESSIONNAME`                                                                                                                   |
|                                                            **Error messages**                                                            |                                                                          Sentence-style capitalization. Enclose in quotation marks when you're referencing error messages in text.  <br /><br />If error messages appear in a list and the introductory text makes clear what those items are, special formatting isn't necessary.                                                                        | An error occurred during report processing.   <br />If you see the error message "Placeholder text in a content control contains items that aren't valid," remove floating objects, revision marks, or content controls from placeholder text, and try again. |
|                                                             **Event names**                                                              |                                                                                                        Code style.                                                                                                        |                                                                                                            In the `OnClick` event procedure ....                                                                                                             |
|                                               **Fields (members of a class or structure)**                                               |                                                                                                        Code style.                                                                                                        |                                                                                                                 `IfHeight`<br />`biPlanes`                                                                                                                 |
|                                                           **File attributes**                                                            |                                                                                                                    All lowercase.                                                                                                                    |                                                           The `attrib` command displays, sets, or removes the read-only, archive, system, and hidden attributes assigned to files or directories.                                                            |
|                                                         **File name extensions**                                                         |                                                                                                                    All lowercase.                                                                                                                    |                                                                                                                         .mdb<br />.doc                                                                                                                         |
|                                                  **File names (user-defined examples)**                                                  |                                                                          Apply code style if used in code. Use bold or plain text if referencing UI.                                                                           |                                                                                                             `MyTaxesFor2025`<br /> My Taxes for 2025                                                                                                             |
|                                          **Folder and directory names (user-defined examples)**                                          |                                                                Apply code style if used in code. Use bold or plain text if referencing UI.                                                                  |                                                                                                  `MyFiles\Accounting\Payroll\VacPay`<br />Vacation and sick pay                                                                                                  |
|                                                        **Functions (predefined)**                                                        |                                                                                                         Code style.                                                                                                         |                                                                                                  `CompactDatabase`<br />`CWnd::CreateEx`<br />`FadePic`                                                                                                  |
|                                                               **Handles**                                                                |                                                                                                                    Code style. All uppercase.                                                                                                                    |                                                                                                                              `HWND`                                                                                                                              |
|                                               **Keywords (language and operating system)**                                               |                                                                                         Code style. Capitalization follows the API.                                                                                          |                                                                                                             `main`<br />`True`<br />`void`                                                                                                             |
|                                                          **Logical operators**                                                           |                                                                                                                 Code style.                                                                                                                 |                                                                                                                      `AND`<br />`XOR`                                                                                                                      |
|                                                                **Macros**                                                                |                                                                                    Code style.                                                                                    |                                                                                                                   `LOWORD`<br />`MASKROP`                                                                                                                    |
|                                                   **Markup language elements (tags)**                                                    |                                                                                                             Code style.                                                                                                             |                                                                                                `<img>`<br />`<input type="text">`<br />`<!DOCTYPE html>`                                                                                                |
|                                                 **Mathematical constants and variables**                                                 |                                                                                                                       Italic.                                                                                                                        |                                                                                                                         *a2 + b2 = c2*                                                                                                                         |
|                                                               **Members**                                                                |                                                                                                             Code style.                                                                                                             |                                                                                                                     `ulNumCharsAllowed`                                                                                                                      |
|                                                               **Methods**                                                                |                                                                                                             Code style.                                                                                                             |                                                                                                               `OpenForm()`<br />`GetPrevious()`                                                                                                                |
|                                                              **New terms**                                                               |                                                                             Italicize the first mention of a new term if you're going to define it immediately in text.                                                                              |                                                                                             Microsoft Exchange consists of both *server* and *client* components.                                                                                              |
|                                                              **Operators**                                                               |                                                                                                                        Bold. Use code style for code-related operators.                                                                                                                         |                                                                                                                      **+, -**<br />`sizeof`                                                                                                                      |
|                                                              **Parameters**                                                              |                                                                                                            Code style.                                                                                                            |                                                                                                           `Hdc`<br />`grfFlagClientBinding`                                                                                                            |
|                                              **Placeholders (in syntax and in user input)**                                              |                                                                                                                       Italic when placeholder element is UI text. Use angle brackets for code placeholders when angle brackets aren't part of the language syntax.                                                                                                                         |                                                                                                           Enter *password*.<br /> `/v: <version>`                                                                                                       |
|                                                                **Ports**                                                                 |                                                                                                                    All uppercase.                                                                                                                    |                                                                                                                              LPT1                                                                                                                              |
|                                               **Products, services, apps, and trademarks**                                               |                         Usually title-style capitalization. Check the Microsoft trademark list for capitalization of trademarked names.                          |                                                               Microsoft Arc Touch Mouse<br />Microsoft Word<br />Surface Pro<br />Notepad<br />Network Connections<br />Makefile<br />RC program                                                               |
|                                                              **Properties**                                                              |                                                                                                         Code style.                                                                                                         |                                                                                                  `M_bClipped`<br />`AbsolutePosition`<br />`Message ID`                                                                                                  |
|                                                              **Registers**                                                               |                                                                                                  Code style.                                                                                                           |                                                                                                                               `DS`                                                                                                                               |
|                                                          **Registry settings**                                                           | Subtrees (first-level items) all uppercase. Separated by underscores. Usually code style.<br />Registry keys (second-level items) follow the capitalization of the UI.<br />Registry subkeys (below the second level) follow the capitalization of the Regedit UI. |                                                                     `HKEY_CLASSES_ROOT`<br />`HKEY_LOCAL_MACHINE`<br />`SOFTWARE`<br />`ApplicationIdentifier`                                                                      |
|                                                              **Statements**                                                              |                                                                                                             Code style.                                                                                                              |                                                                                                                  `IMPORTS`<br />`LIBRARY`                                                                                                                  |
|                                                              **Structures**                                                              |                                                                                                         Code style.                                                                                                         |                                                                                                                         `ACCESSTIMEOUT`                                                                                                                          |
|                                                               **Switches**                                                               |                                                                                                               Code style. Usually lowercase.                                                                                                               |                                                                                                                      `build: commands`                                                                                                                       |
|                                                          **UI text or strings**                                                          |                                                                       Treatment varies; see Formatting text in instructions. Sentence-style capitalization.                                                                      |     Import from file<br />Create a new resource<br />See all your resources<br />Manually trigger a flow<br />Report a bug     |
|                                                                 **URLs**                                                                 |                                      All lowercase for complete URLs. If necessary, line-break long URLs before a slash. Don't hyphenate. Use code style if referring to URLs in code. <br />**See also** URLs and web addresses.                                       |                                                                                                    www<span></span>.microsoft.com<br />www.microsoft.com/download<br />`const url = "https://www.microsoft.com"`                                                                                                         |
|                                                              **User input**                                                              |                                          Usually lowercase, unless case sensitive. Bold. Use italic only for placeholders.                                           |                                                                                                       Enter **hello world**<br />Enter *password*                                                                                                       |
|                                                                **Values**                                                                |                                                                                                                    Code style. All uppercase.                                                                                                                    |                                                                                                                         `DIB_PAL_COLORS`                                                                                                                         |
|                                                              **Variables**                                                               |                                                                                                                  Usually code style.                                                                                                                   |                                                                                                           `bEmpty`<br />`m_nParams`<br />`file_name`                                                                                                           |
|                                                         **XML schema elements**                                                          |                                                                                                             Code style. Usually surrounded with angle brackets.                                                                                                          |                                                                                                      `<configuration>`<br /> `ElementType` element                                                                                                     |

## Chatbots and virtual agents

A virtual agent is a type of bot that can be used to:

- Provide information and answers. 
- Complete tasks like booking meetings or buying tickets.

Before you create a virtual agent, make sure it will add value to the customer experience.

This type of bot is good for tasks where it's easier to ask for what you want rather than navigate through a menu or search for keywords. But a bot isn't a human, and there are some things that it isn't suited for.

Technically speaking, there are two kinds:

- One kind is scripted. It can respond only to questions that it was programmed to understand. 
- Another uses AI, so it can understand what the customer is telling it, and its knowledge grows the more it interacts with people. 

This section includes guidelines and tips to help you create this type of bot:

- Structural and technical considerations
- Writing for bots
- Care and feeding of the bot

**Learn more** Microsoft's AI vision, rooted in research, conversations Bot Framework documentation Responsible bots: 10 guidelines for developers of conversational AI

## Structural and technical considerations

<h2>Clarify intent before acting</h2>

Until you're sure your bot can reliably interpret conversational cues, it should:

- Confirm the customer's intent: "You need to reset your password. Is that right?" 

- Clarify and disambiguate the customer's input when necessary: "OK, we'll reset your password. But first, I'd like to know more. 
Did you forget your password, or are you concerned that someone else has your password? You can say, "I forgot," or "My account is compromised."

Be careful not to overdo it, though. It's better not to annoy the customer with a needless prompt unless misunderstanding the request could cause damage.

<h2>Use buttons and other UI structure to keep users on track</h2>

- Prompt users with actionable statements and buttons to guide the conversation. 

- Offer suggestions when the bot is "confused" about what the user's request is. 

<h2>Pace the conversation carefully</h2>

- Break up messages into separate, readable blocks to make the pace of the conversation feel more natural. 

- Make sure the bot doesn't respond so quickly that it rushes the customer. Add a minimum delay if necessary.  

<h2>Accommodate alternative word order and incomplete requests</h2>

The bot should be able to recognize the customer's request, regardless of how it's phrased.

<h2>Conclude the conversation when the request is resolved</h2>

Mimic the sense of closure typical in human-to-human interaction by wrapping up the conversation. For example: "Is there anything else I can help you with? [No.] OK, then. Have a great day!" Having a sense of completion helps the customer feel like there's a shared goal, reinforces the positive experience, and builds confidence in using the bot.

## Writing for bots



Tailor the tone of the bot's responses to the context. If it's something serious—like billing or 
cybersecurity—be empathetic but brief and straightforward. If it's a more mundane situation (like creating a new account), 
the tone can be more relaxed. And a bot for Xbox can be lighthearted and casual. 

**See** [Microsoft's brand voice](/style-guide/brand-voice-above-all-simple-human)  

## Be honest and build trust 

- Make sure users know that they're not chatting with a person. For example, have the bot introduce itself as a 
virtual support agent. The message can be brief—research shows that customers are usually aware that they're chatting with a bot. 

- Explain what the bot's purpose is and what it can and can't do. Good ways of framing the functionality are suggesting
a first task or place to begin, or providing buttons or shortcuts for the most frequent tasks. 

- Admit when things get messed up. And have a plan for dealing with the situation. 

- Plan for common misspellings and errors. These don't derail human-to-human conversations, and being able to 
accommodate them will build the user's confidence in the bot. 

## Accept—and plan for—the bot's limitations 

There are some questions a bot just won’t have an answer for.  

- Make it clear to the user that the bot has a very specific role. Don't imply an open-ended, "Ask me anything" role. 

- Be prepared for when the bot doesn't know the answer, and have it point the customer in the right direction. 

- Decide what conversational cues will prompt the bot to escalate to a human. At key points in the conversation, 
let the customer know how they can get help from a human, if they want to. 

## Keep it simple, and keep it short 

Customers abandon a chat when the prompts are lengthy. To keep your writing simple and straightforward, use the 
Flesch-Kincaid Grade Level feature in Microsoft Word or an app like Hemingwayapp.com to figure out the grade level 
of your scripts. In general, the lower the grade level, the better. 

## Anticipate mischief 

Plan how the bot should respond when users start to play games with it—for example, asking the same question 
over and over to test it, using offensive language, or asking nonsense questions. An appropriate response shows 
that the bot can be relevant and helpful, if given a chance. Humor can be effective, but be careful: a humorous 
response to an offensive question can backfire.  

## Be a good listener 

- Invite the user into the conversation on a regular basis by asking questions or making suggestions.  

- Respond to the customer in a timely manner. If the bot is taking a while to process the customer's request, 
use, "I'm thinking" or the typing indicator to let the customer know the bot is working on a response.  

- Boost the relevance of the bot's responses by making them specific to the context. For example, say, 
"Here's how you change your privacy settings," not "Here's how you do that." 

## Remember whose side you're on 

The bot is working on behalf of the customer and is there to serve the customer. It's not there for Microsoft's benefit. 

## Watch your pronouns: I, me, my 

The bot uses *I, me,* and *my* to refer to itself. 

When the customer communicates to the bot, they also use *I, me,* or *my.* Make sure those pronouns appear on 
buttons, links, or other elements of the bot that the user selects.  

## Recognize common words 

People are familiar with words like *help, settings, start over,* and *stop.* Make sure your bot recognizes and responds to them.
## Care and feeding of the bot

<h2>Maintain the bot and evaluate its effectiveness over time</h2>

Have a plan for maintaining and evolving the bot. What's working and what isn't? What's your plan for phasing in new and improved features? What can be done better? How will you know when it's time to retire your bot?

<h2>Learn from customers</h2>

- Make it possible for people to give you feedback directly through the bot. Ask if they got what they were looking for. 
Give them a way to tell you what they wanted if the results weren't what they expected.

- Label your content blocks in the flow. That way, you can identify the content blocks that users leave from the most, 
figure out why, and improve them.

- Extend or improve the experience when appropriate. For example, if the customer gives positive feedback, suggest 
they rate the app. If the experience didn't meet their expectations, provide a link to support.
