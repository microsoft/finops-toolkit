export interface Citation {
  id: string;
  reindex_id?: string;
  filepath?: string;
  url?: string;
  title?: string;
  snippet?: string;
  section?: string; // Added explicitly for clarity
  content?: string; // Content from the backend
  chunkId?: string;
  part_index?: number;
  document_name?: string;
  filename?: string; // Backend sometimes includes this
  source_info?: string; // Backend sometimes includes this
}

export interface AskResponse {
  answer: string;
  citations: Citation[];
  generated_chart?: string | null;
}

export type ParsedAnswer = {
  citations: Citation[]
  markdownFormatText: string;
  generated_chart: string | null;
} | null;

/**
 * Enumerates citations by filepath to handle multiple citations from the same source
 */
export const enumerateCitations = (citations: Citation[]) => {
  const filepathMap = new Map();
  for (const citation of citations) {
    const { filepath } = citation;
    let part_i = 1;
    if (filepathMap.has(filepath)) {
      part_i = filepathMap.get(filepath) + 1;
    }
    filepathMap.set(filepath, part_i);
    citation.part_index = part_i;
  }
  return citations;
};

/**
 * Parses an API response to extract and format citations
 */
export function parseAnswer(answer: AskResponse): ParsedAnswer {
  if (typeof answer.answer !== "string") return null;
  
  let answerText = answer.answer;
  console.log("Citations in API response:", answer.citations?.length);
  
  // Support both traditional [docN] format and simple [N] format if that's what the API returns
  const citationLinks = answerText.match(/\[(doc\d\d?\d?)]/g) || answerText.match(/\[(\d+)\]/g);
    // If no citations are found in the text, or no citations data exists
  if (!citationLinks || citationLinks.length === 0 || !answer.citations || answer.citations.length === 0) {
    // If citations data exists but no links in the text, we'll still process the citations
    if (answer.citations && answer.citations.length > 0) {
      console.log("No citation links in text, but", answer.citations.length, "citations exist in data");
      return {
        citations: enumerateCitations([...answer.citations]),
        markdownFormatText: answerText,
        generated_chart: answer.generated_chart || null
      };
    }
    
    // No citations at all
    console.log("No citations found in text or data");
    return {
      citations: [],
      markdownFormatText: answerText,
      generated_chart: answer.generated_chart || null
    };
  }
  
  // Determine if we're using [docN] format or simple [N] format
  const isDocFormat = citationLinks[0].includes('doc');
  const lengthDocN = isDocFormat ? '[doc'.length : '['.length;

  // Process and filter citations
  let filteredCitations = [] as Citation[];
  let citationReindex = 0;
  
  citationLinks.forEach(link => {
    // Replacing the links/citations with number
    const citationIndex = link.slice(lengthDocN, link.length - 1);
    const indexNumber = Number(citationIndex) - 1;
    
    // Ensure the citation index is valid
    if (indexNumber >= 0 && indexNumber < answer.citations.length) {
      // Deep copy the citation object to avoid mutations
      const citation = JSON.parse(JSON.stringify(answer.citations[indexNumber])) as Citation;
      
      if (!filteredCitations.find(c => c.id === citationIndex) && citation) {
        // Use split and join as a substitute for replaceAll for broader compatibility
        answerText = answerText.split(link).join(`[${++citationReindex}]`);
        citation.id = citationIndex; // original doc index to de-dupe
        citation.reindex_id = citationReindex.toString(); // reindex from 1 for display
        filteredCitations.push(citation);
      }
    }
  });

  filteredCitations = enumerateCitations(filteredCitations);

  return {
    citations: filteredCitations,
    markdownFormatText: answerText,
    generated_chart: answer.generated_chart || null
  };
}

/**
 * Formats citations for display in the citation panel
 */
export function formatCitationsForMarkdown(citations: Citation[]): string {
  if (!citations || citations.length === 0) return '';

  const citationLines = citations.map(citation => {
    const id = citation.reindex_id || citation.id;
    const titleText = citation.title || 'Untitled Document';
    
    // Get a short description from the snippet if available
    let description = '';
    if (citation.snippet) {
      // Clean and trim the snippet to create a concise description
      description = `: ${citation.snippet.replace(/\n/g, ' ').trim()}`;
      if (description.length > 100) {
        description = `${description.substring(0, 97)}...`;
      }
    }    // Format document source info
    const docInfo = [];
      // Use document_name if available, otherwise extract from filepath
    if (citation.document_name) {
      docInfo.push(`**Document**: ${citation.document_name}`);
    } else if (citation.filepath) {
      const pathParts = citation.filepath.split(/[/\\]/);
      const fileName = pathParts[pathParts.length - 1];
      docInfo.push(`**Document**: ${fileName}`);
    }
    
    // Add filepath info if available
    if (citation.filepath) {
      const pathParts = citation.filepath.split(/[/\\]/);
      // Show path without filename
      if (pathParts.length > 1) {
        const dirPath = pathParts.slice(0, -1).join('/');
        docInfo.push(`**Path**: ${dirPath}`);
      }
    }
    
    // Add chunk info if available
    if (citation.chunkId) {
      docInfo.push(`**Chunk**: ${citation.chunkId}`);
    }

    // Format citation line
    let citationLine = `[${id}] ${titleText}${description}`;
    
    // Add document info if available
    if (docInfo.length > 0) {
      citationLine += `\n    ${docInfo.join(' | ')}`;
    }

    return citationLine;
  });

  return `## 📚 Citations and References\n${citationLines.join('\n\n')}`;
}

/**
 * Converts API Citation format to CitationData format used by CitationHandler
 */
export function convertToCitationData(citations: Citation[]) {
  if (!citations || citations.length === 0) return [];
  
  return citations.map(citation => {
    // Get a reasonable title - prefer document_name, then title, then extract from filepath
    let title = citation.document_name || citation.title;
    if (!title && citation.filepath) {
      // Extract filename from path with support for both / and \ path separators
      const pathParts = citation.filepath.split(/[/\\]/);
      title = pathParts[pathParts.length - 1];
    }
    if (!title && citation.url) {
      try {
        const url = new URL(citation.url);
        title = url.hostname;
      } catch {
        title = citation.url;
      }
    }
    
    const finalTitle = title || 'Untitled Document';
    const isEducational = 
      finalTitle.toLowerCase().includes('focus') || 
      finalTitle.toLowerCase().includes('finops');    // Look for file path in local sources only
    // Only use the filepath if it's a local path (not an external URL)
    // This ensures we only use local file references
    const filepath = citation.filepath && !citation.filepath.startsWith('http') 
      ? citation.filepath 
      : undefined;
    
    // Do not use any external URLs for citations
    // If we don't have a valid local filepath, we'll use undefined
    // This ensures citations stay within the app and don't link externally
    // For AI Search index citations, make sure we use internal references only
    // This will ensure that all citations are handled internally
    
    return {
      id: citation.reindex_id || citation.id,
      title: finalTitle,
      section: citation.section || (citation.part_index ? `Part ${citation.part_index}` : undefined),
      filepath: filepath,
      content: citation.content || citation.snippet || undefined,
      chunkId: citation.chunkId || undefined,
      isEducational: isEducational,
      sourceInfo: citation.source_info // Include source_info in case needed
    };
  });
}
