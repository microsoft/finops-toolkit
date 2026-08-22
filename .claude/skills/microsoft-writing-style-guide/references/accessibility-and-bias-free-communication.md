# Accessibility and bias-free communication

## Accessibility Guidelines and Requirements

Microsoft devices and services empower people of all abilities, around the globe—at home, at work,
and on the go—to do the activities they value most. 

This section provides an overview of accessibility guidelines:

  - [Writing for all abilities](/style-guide/accessibility/writing-all-abilities)
  - [Colors and patterns in text, graphics, and design](/style-guide/accessibility/colors-patterns-text-graphics-design) 
  - [Graphics, design, and media](/style-guide/accessibility/graphics-design-media)

**See also** [Accessibility term collection](/style-guide/a-z-word-list-term-collections/term-collections/accessibility-terms)

**Learn more**  
[Microsoft Accessibility site](https://www.microsoft.com/accessibility/)
## Writing for all abilities

Microsoft style—clean, simple design and crisp, clear content—is easier for all readers to use, so nearly every writing recommendation in this guide will improve accessibility. Pay special attention to the following guidelines.

## Put the person first

In general, use people-first language (refer first to the person, followed by the disability). To ensure clarity and consistency, this should be the default unless you know a specific audience prefers identity-first language. When you must describe specific disabilities or people with specific disabilities, consult approved Accessibility terminology.

## Write brief, meaningful, and focused text

**Be especially clear and concise** in instructions for product setup, basic features, input methods, and accessibility features.

**Lead with what matters most,** so readers know immediately where to focus their attention.

**Keep paragraphs short and sentence structure simple.** Aim for one verb per sentence. Read text aloud and imagine it spoken by a screen reader.

**Use parallel writing structures for similar things.** For example, use singular nouns for each top-level heading. Or, use a verb to start each item in a list.

**Spell out words like** ***and, plus,*** **and** ***about.*** Screen readers can misread or skip text that uses special characters like the plus sign (+) and tilde (~).  See special characters for more detailed information.

**Write brief but meaningful link text.** Be descriptive—links should make sense without the surrounding text.

**Distinguish link text visually.** Use redundant visual cues, such as both color and underline.

**Don’t force line breaks** (also known as hard returns) within sentences and paragraphs. They may not work well in resized windows or with enlarged text.

## Use content structure and location to communicate

**Emphasize important points visually and stylistically.** Lists, headings, and tables reinforce relationships between concepts. Provide a brief description of what a table contains immediately preceding it in the text, and use concise and specific column headings.

**Use heading levels** instead of text formatting to communicate the hierarchy of content.

**Don’t use directional terms as the only clue to location.** *Left, right, up, down, above,* and *below* aren’t very useful for people who use screen-reading software. Instead, use specific language that conveys context, such as “the first item in the following list” or “on the toolbar.”

## Document alternate input methods

**In product documentation, document all supported modes of interaction, input commands, and keyboard shortcuts.** Include mice, keyboards, voice recognition devices, game controllers, gestures, and other interaction modes.

In procedures and instructions, use generic verbs that apply to all input methods and devices. Avoid verbs like *click* (mouse) and *swipe* (touch) that don't make sense with some alternative input methods used for accessibility.

**Learn more** Describing alternative input methods

Describing interactions with UI

## Colors and patterns in text, graphics, and design

Choose colors and patterns carefully. High contrast may improve readability for people who have low vision. For people with some types of color blindness, certain color combinations are difficult to distinguish.

**Don’t convey information with color alone.** For example, use both color and underlined text for links, and use pattern and color to differentiate information in charts and graphs. Remember that high-contrast personalization themes in Windows alter text color.

**Don’t hard-code colors.** They can become illegible in high-contrast themes.

**Choose color combinations with a minimum contrast ratio of 4.5:1.** Don’t use low-contrast or hard-to-read color combinations, such as light green and white or red and green.

**Don’t use screens or tints in art.**

**Don’t use screened or shaded backgrounds, watermarks, or other images behind text.** Reduced contrast makes text harder to read and hinders screen readers.

## Alternative text (alt text)

Alternative text (abbreviated as *alt text*) is a textual replacement for images, including graphics, photographs, charts, and screenshots. Alt text an essential part of accessibility because it benefits users who can't view or process images. The purpose is to provide an equivalent user experience by communicating the same basic information that other users gain from looking at the image.

In your alt text, accurately but concisely convey the image's purpose. Writing good alt text isn't about describing every detail. It requires interpretation and judgment.

## General guidelines

- Add alt text to all images that convey important meaning.

- Images that are purely decorative don't need alt text. An example is the image of an icon that immediately follows the icon name in text.

For decorative images in web content, use null alt text (`alt=""`) instead of omitting the `alt` attribute.

- Begin alt text with a capital letter. End it with a period, even if it's just a fragment, if doing so is practical for the image type.

- Don't start alt text with a general word such as "Image." Screen readers already announce images as images. Instead, start by specifying what the image is; for example, a drawing, photograph, diagram, chart, or screenshot.

- Don't use the file name of an image as alt text.

- If text is embedded in an image, include it in the alt text if surrounding content doesn't include that information. You might need to paraphrase if you suspect that screen readers would have difficulty reading it.

- Limit the length to 150 characters. If an image is complex, consider including a detailed description in the surrounding text or in linked content.

- Avoid simply repeating surrounding text in alt text.

- If an image has a caption, ensure that the caption and alt text aren't redundant.

## Considerations for button and link images

- If a button or link has an image but no text, the image must have alt text.

- Alt text should focus on what the button or link does, not what the image shows.

- Don't start the alt text with "Button" or "Link." Screen readers already announce buttons as buttons and links as links.

- If a button or link has both an image and text, it typically doesn't need alt text because it's just decorative.

## Examples

| Scenario | Appropriate alt text | Inappropriate alt text | Notes |
| -------- | -------------------- | ---------------------- | ----- |
| A procedure in technical content includes a screenshot that illustrates preceding steps by showing a tab where users enter information for creating an account. | Screenshot of the tab for creating an account. | Screenshot of the 'Create an account' tab with boxes for username, organization, and product tier and a Create button highlighted. | There's no reason to describe every detail in the interface because the procedural steps provide that information. |
| The button that opens an app's user settings has no text label and is identified only by a graphic of two gearwheels. | Open user settings. | Image of two interlocking gears, one larger than the other. | If you simply describe what the image looks like, users won't know the purpose of the button. |
| A social media post has, as its main content, a photo that shows reactions to an announcement at a product launch event. | A group of people smiling, cheering, and taking photos of a speaker. | Photograph from the launch event. | In this case, the image's meaning lies in the details of the photo and what the people are doing. The alt text needs to be descriptive to provide an equivalent user experience. |
| A search button for a website consists of a graphic of a magnifying glass but no label text. | Search this site. | Magnifying glass button for searching. | What the button does is more important than what the button image shows. |
| A link for chatting with a support agent consists of a photo of woman wearing a headset but doesn't provide link text. | Open an online chat session with customer support. | Photo of a smiling woman wearing a headset. | The alt text acts as link text, so what the link does is more important than what it looks like. |
| A link to a product upgrade page consists of the link text **Upgrade now**, followed by a graphic of the product logo. | (Not applicable.) | Graphic of the product logo. | The graphic is decorative, so it doesn't need alt text. Instead, provide a null value (`alt=""`). |

## See also

Graphics, design, and media Everything you need to know to write effective alt text

## Graphics, design, and media

Websites need to be accessible to everyone. Websites that are accessible to people with disabilities also support customers with various browsers, settings, and devices or who use older technologies.

In general, use clean and simple graphic design. Provide alternate ways to get the information that's conveyed by pictures, multimedia, and image maps.

## Design

**Keep text within a rectangular grid** for visibility and ease of scanning.

**Format tables** according to the Web Content Accessibility Guidelines (WCAG) 2.0.

**If you use frames,** provide alternative pages without them.

**Don't use scrolling marquees** unless the customer has control over them.

## Images, image maps, and multimedia

**Provide clear descriptions that don't require pictures,** or provide both. Make sure the reader can get the whole story from either the picture or the written description.

**Provide text alternatives for all elements that aren't text but convey important meaning.** These elements might include images (such as graphics, photographs, charts, or screenshots), audio, video, or animations (including animated GIFs). Here are some examples of text alternatives:

- Alt text for images, unless they're purely decorative. Learn more in Alternative text (alt text).
- Closed captions, transcripts, or descriptions for audio and video content. Video content requires both closed captions and audio descriptions. If a video has a thumbnail image, add alt text to the thumbnail.
- Detailed descriptions in the surrounding text, or in a separate document that you link to, for complex elements or images that require long alt text.

**Provide text links** in addition to image maps.

**Plan links and image-map links to support Tab key navigation** with bidirectional text.

## Bias-free communication

Microsoft technology reaches every part of the globe, so it's critical that all our communications are inclusive and diverse.

**Use gender-neutral alternatives for common terms.**


|         **Use this**         | **Not this** |
|------------------------------|--------------|
|       chair, moderator       |   chairman   |
| humanity, people, humankind  | man, mankind |
|       operates, staffs       |     mans     |
|     sales representative     |   salesman   |
|   synthetic, manufactured    |   manmade    |
| workforce, staff, personnel |   manpower   |

**Don't use *he, him, his, she, her,* or *hers* in generic references.** Instead:  
- Rewrite to use the second person (*you*).  
- Rewrite the sentence to have a plural noun and pronoun.
- Use *the* or *a* instead of a pronoun (for example, "the document"). 
- Refer to a person's role (*reader, employee, customer,* or *client,* for example).
- Use *person* or *individual.*  

If you can't write around the problem, it's OK to use a plural pronoun (*they, their,* or *them*) in generic references to a single person. Don't use constructions like *he/she* and *s/he.*


|         **Use this**         | **Not this** |
|------------------------------|--------------|
|    If you have the appropriate rights, you can set other users' passwords.<br />A user with the appropriate rights can set other users' passwords.       |   If the user has the appropriate rights, he can set other users' passwords.   |
| Developers need access to servers in their development environments, but they don't need access to the servers in Azure.                                       | A developer needs access to servers in his development environment, but he doesn't need access to the servers in Azure. |
|       When the author opens the document ….       |     When the author opens her document ….     |
|     To call someone, select the person's name, select **Make a phone call**, and then choose the number you'd like to dial.                                   |   To call someone, select his name, select **Make a phone call**, and then select his number.   |
|   If you want to call someone who isn't in your Contacts list, you can dial their phone number using the dial pad.                                             |   If you want to call someone who isn't in your Contacts list, you can dial his or her phone number using the dial pad.    |

**When you're writing about a real person, use the pronouns that person prefers,** whether it's *he, she, they,* 
or another pronoun. It's OK to use gendered pronouns (like *he, she, his,* and *hers*) when you're 
writing about real people who use those pronouns themselves.

It's also OK to use gendered pronouns in content such as direct quotations and the titles of works and when gender 
is relevant, such as discussions about the challenges that women face in the workplace.  
**Examples**  
The skills that Claire developed in the Marines helped her move into a thriving technology career.  
Anthony Lambert is executive vice president of gaming. With his team and game development partners, 
Lambert continues to push the boundaries of creativity and technical innovation.  
The chief operating officer of Munson's Pickles and Preserves Farm says, "My great uncle Isaac, who employed  
his brothers, sisters, mom, and dad, knew that they—and his customers—were depending on him."  
Do you have a daughter? Here are a few things you can do to inspire and support her interest in STEM subjects.  

**In fictitious scenarios, strive for diversity and avoid stereotypes in job roles.** Choose names that reflect 
a variety of gender identities and cultural backgrounds. 

**In text and images, represent diverse perspectives and circumstances.** Depict a variety of people from all 
walks of life participating fully in activities. Be inclusive of gender identity, race, culture, ability, age,
sexual orientation, and socioeconomic class. Show people in a wide variety of professions, educational settings, 
locales, and economic settings. Avoid using examples that reflect primarily a Western or affluent lifestyle. 
In drawings or blueprints of buildings, show ramps for wheelchair accessibility. 

**Be inclusive of job roles, family structure, and leisure activities.** If you show various family groupings, 
consider showing nontraditional and extended families. 

**Be mindful when you refer to various parts of the world.** If
you name cities, countries, or regions in examples, make sure
they're not politically disputed. In examples that refer to several
regions, use equivalent references—for example, don't mix
countries with states or continents.

**Don't make generalizations about people, countries, regions, and cultures,** not even positive or neutral generalizations. 

**Don't use slang,** especially if it could be considered cultural appropriation, such as *spirit animal.*  

**Don't use profane or derogatory terms,** such as *pimp* or *bitch.*    

**Don't use terms that may carry unconscious racial bias or terms associated with military actions, politics, or historical events and eras.** See [Militaristic language](/style-guide/militaristic-language) for more information.


|    **Use this**    |       **Not this**       |
|--------------------|--------------------------|
| primary/subordinate |       master/slave       |
| perimeter network  | demilitarized zone (DMZ) |
|  stop responding   |           hang           |

**Focus on people, not disabilities.** For example, talk about readers who are blind or have low vision and customers with limited dexterity. Don't use words that imply pity, such as *stricken with* or *suffering from.* Don't mention a disability unless it's relevant. For more information, see the [Accessibility term collection](/style-guide/a-z-word-list-term-collections/term-collections/accessibility-terms). 

**Inclusive language** Use title-style capitalization for Asian, Black and African American, Hispanic and Latinx, Native American, Alaska Native, Native Hawaiian, Pacific Islander, and Indigenous Peoples. Microsoft style is to lowercase multiracial and white. 

**Learn more** For more information about writing that conveys respect to all people and promotes equal opportunities, see the [Guidelines for Inclusive Language](https://www.linguisticsociety.org/content/guidelines-inclusive-language "Linguistic Society of America's guidelines for inclusive language") from the Linguistic Society of America. 

**See also** [Militaristic language](/style-guide/militaristic-language), [Accessibility guidelines and requirements](/style-guide/accessibility/accessibility-guidelines-requirements), [Global communications](/style-guide/global-communications/)
## Militaristic language

Avoid using terms associated with violence and military actions unless you are referring to physical combat operations.  

In the context of cybersecurity at Microsoft, use the following recommendations in the table of militaristic terms. 


|         **Use this**                       |                   **Not this**              |
|----------------------------------------------|-------------------------------------------|
|       address; protect against; respond to       |   combat; fight; eliminate               |
| cyberattack chain   | (cyber) kill chain  |
|      cyberattacker; bad actor; threat actor        |     attacker; adversary     |
|     impact    |   blast radius   |
|   multilayered approach; defense-in-depth cybersecurity    |   defense-in-depth approach     |
| protect; safeguard; defend  |   guard; ward    |
| secured  |   locked down   |
| security; protection; defense  |   fortifications; first line of defense; frontlines    |
| security teams; security analysts; defenders  |   frontline analysts    |
| vulnerabilities; points of access; external exposure  |   external attack surface    |


**Attack** 
It’s ok to use *attack* if there’s context in front of it describing what kind of attack it is. For example, say, *Early detection is critical to preventing damage from malware attacks* instead of *Get protection from sophisticated attacks*. 

If there’s no context before attack that describes what kind of attack it is, add *cyber*- in front of threat so it reads *cyberattack*, all one word, no space, no hyphen.  

**Example**  
Uncover and defend against advanced cyberattacks across your entire digital estate. 

**Defend, defense, and defenses**
It’s ok to use *defend* and *defenses* if there’s context in the same sentence that makes it clear they’re referring to cybersecurity. 

**Examples**  
Learn how to defend your cloud and on-premises workloads. 
Extend your defenses across endpoints and clouds with Microsoft Security. 

**External attack surface**
It’s ok to use this phrase when discussing external attack surface management, external attack surface management capabilities, or the product Microsoft Defender External Attack Surface Management. 

Don’t use the phrase *external attack surface* when referring to a customer’s points of access that are potentially vulnerable to an attack. Use *vulnerabilities*, *points of access*, or *external exposure* instead. 

**Threat**
It’s ok to use *threat* if there’s context in front of it describing what kind of threat it is.   

**Example**  
Explore an integrated identity threat and response solution.  

If there’s no context before *threat* that describes what kind of threat it is, add *cyber*- in front of threat so it reads *cyberthreat*, all one word no space no hyphen. 

**Example**  
Identify and remediate cyberthreats in the cloud and on-premises. 

**Threat intelligence**
It’s ok to use *threat intelligence* if the surrounding context makes it clear it’s related to cybersecurity. Don’t shorten to *threat intel*.  

**Example**  
Get actionable insights into new and emerging cyberthreats with dynamic threat intelligence. 

**Never use**
These terms are overtly militaristic and should never be used in the context of cybersecurity at Microsoft (though they may be used to refer to physical combat operations): 

air cover  
bomb, email bomb, mail bomb, time bomb  
enemy, enemies, enemy lines  
go on the offensive  
invade, invasion  
missile, torpedo  
nuke, go nuclear  
strike  
troops  

See also [Bias-free communication](/style-guide/bias-free-communication)