// filepath: c:\_repos\finops-toolkit-1\src\finley\frontend\src\components\CitationHandler.tsx
import React, { useState, useEffect, useRef } from 'react';
import './CitationHandler.css';
import { Citation, convertToCitationData } from '../utils/citationUtils';

declare global {
  interface Window {
    handleCitationClick: (id: string) => void;
  }
}

interface CitationData {
  id: string;
  title: string;
  section?: string;
  filepath?: string;
  content?: string;
  isEducational?: boolean;
  chunkId?: string;  // Added chunkId property
  document_name?: string; // Added for display
  file_name?: string; // Added for file name
}

interface CitationHandlerProps {
  content: string;
  onContentChange?: (newContent: string) => void;
  citations?: Citation[];
  defaultView?: 'compact' | 'detailed'; // NEW
}

const CITATION_REGEX = /\[(\d+)\]/g;
const SUPERSCRIPT_CITATION_REGEX = /(\d+)\s*(?=[^0-9]|$)/g; // Match superscript numbers
const CITATION_SECTION_REGEX = /## 📚 Citations and References([\s\S]*?)(?:$|(?=## ))/;

const CitationHandler: React.FC<CitationHandlerProps> = ({
  content,
  onContentChange,
  citations: providedCitations,
}) => {
  const [citations, setCitations] = useState<CitationData[]>([]);
  const processedContentRef = useRef<string | null>(null);
  const contentProcessedRef = useRef<boolean>(false);
  useEffect(() => {
    if (!content) return;

    if (processedContentRef.current !== content) {
      contentProcessedRef.current = false;
    }

    if (contentProcessedRef.current) return;
    contentProcessedRef.current = true;

    // --- DEBUG LOGGING ---
    console.log('CitationHandler: providedCitations', providedCitations);
    // --- END DEBUG LOGGING ---

    if (providedCitations && providedCitations.length > 0) {
      // Normalize citations to always have document_name and file_name
      const formattedCitations = convertToCitationData(providedCitations as Citation[]);
      const normalized = normalizeCitations(formattedCitations);
      console.log('CitationHandler: normalized citations', normalized);
      setCitations(normalized);

      let processedText = content;
      processedText = processedText.replace(
        CITATION_REGEX,
        (match, id) => {
          const href = `#citation-${id}`;
          return `<a href="${href}" class="ftk-citation-ref" data-citation-id="${id}" role="button" tabindex="0" aria-label="Citation ${id}">${match}</a>`;
        }
      );

      if (onContentChange && processedContentRef.current !== processedText) {
        processedContentRef.current = processedText;
        onContentChange(processedText);
      }
      return;
    }

    // --- Always parse (Citations: ...) and remove from content ---
    let mainContent = content;
    let foundCitations = false;
    // Legacy citation extraction (e.g., (Citations: ...))
    // Regex: (Citations: 1, 2, 3)
    const legacyCitationRegex = /\(Citations?: ([^)]+)\)/i;
    const citationTextMatch = content.match(legacyCitationRegex);
    if (citationTextMatch) {
      // Remove unused 'match' variable warning by omitting it
      const ids = citationTextMatch[1]
        .split(',')
        .map((id) => id.trim())
        .filter(Boolean);
      if (ids.length > 0) {
        const extractedCitations = ids.map((id, idx) => ({
          id: String(idx + 1),
          title: id,
          document_name: id,
        }));
        setCitations(normalizeCitations(extractedCitations));
        foundCitations = true;
      }
    }    // --- Extract (Source: ...) legacy citation ---
    // Example: (Source: FinOps Open Cost and Usage Specification, what-is-focus.md)
    // Also support various formats like:
    // (Source: Document name)
    // (Source: Document name, filename.md)
    // (Sources: Doc1, Doc2)
    // (Reference: Document name)
    // (From: Document name)
    // Even plain text at the end like "Source: Document name"
    // Or References: followed by a bullet list of sources
    
    // Enhanced regex pattern for more flexible citation format detection
    const sourceCitationRegex = /(?:\((?:Source|Reference|From|Ref|Citation):?\s*([^)]+)\))|(?:(?:Source|Reference|From|Ref|Citation)s?:[ \t]+([^\n]+)(?:\n|$))|(?:See(?:\salso)?:[ \t]+([^\n]+)(?:\n|$))/gi;
    
    console.log('Checking for source citations');
    const sourceCitationMatches = [...content.matchAll(sourceCitationRegex)];
    console.log('Found source citations:', sourceCitationMatches.length, sourceCitationMatches);
    
    if (sourceCitationMatches.length > 0) {      const extractedCitations = sourceCitationMatches.map((match, idx) => {
        // Get the citation text from either the first or second capture group
        const citationText = (match[1] || match[2] || '').trim();
        
        // Try to intelligently split the citation into document name and file name
        let docName = citationText;
        let fileName = '';
        
        // First check for explicit file patterns
        const filePattern = citationText.match(/(\w+[-_]?\w+\.(pdf|docx|xlsx|html?|md|json|txt|csv))/i);
        if (filePattern) {
          fileName = filePattern[0];
          // Remove the file name from doc name if it's at the end
          if (docName.endsWith(fileName)) {
            docName = docName.substring(0, docName.length - fileName.length).trim();
            // Remove trailing comma if present
            if (docName.endsWith(',')) {
              docName = docName.substring(0, docName.length - 1).trim();
            }
          }
        } else {
          // If no file pattern found, try splitting on last comma
          const lastComma = citationText.lastIndexOf(',');
          if (lastComma !== -1) {
            // Check if what's after the comma might be a file name
            const potentialFile = citationText.slice(lastComma + 1).trim();
            if (potentialFile.length < 40 && !potentialFile.includes(' ')) {
              fileName = potentialFile;
              docName = citationText.slice(0, lastComma).trim();
            }
          }
        }
        
        console.log(`Processing citation ${idx + 1}:`, { docName, fileName, original: citationText });
        
        return {
          id: String(idx + 1),
          title: docName,
          document_name: docName,
          file_name: fileName,
        };
      });
        console.log('Extracted citations:', extractedCitations);
      
      // Set the citations state
      const normalizedCitations = normalizeCitations(extractedCitations);
      console.log('Normalized citations:', normalizedCitations);
      
      // Debug log each citation's details
      normalizedCitations.forEach((citation, index) => {
        logCitationDetails(citation, index);
      });
      
      setCitations(normalizedCitations);
      foundCitations = true;
      
      // Replace all citation patterns in the content with clickable superscript citation references
      let replacementIndex = 0;
      mainContent = mainContent.replace(sourceCitationRegex, () => {
        const citationId = String(++replacementIndex);
        const href = `#citation-${citationId}`;
        return `<sup><a href="${href}" class="ftk-citation-inline" data-citation-id="${citationId}" role="button" tabindex="0" aria-label="Citation ${citationId}">${citationId}</a></sup>`;
      }).trim();
    }
    // Only remove the citation text if we are rendering cards
    if (foundCitations) {
      mainContent = mainContent.replace(/\(Citations: [^)]+\)/i, '').trim();
    }

    const citationMatch = mainContent.match(CITATION_SECTION_REGEX);
    const extractedCitations: CitationData[] = [];
    
    if (citationMatch) {
      const citationSection = citationMatch[0];
      mainContent = content.replace(citationSection, '');

      const citationLines = citationSection.split('\n').filter(line => line.trim());
      citationLines.forEach(line => {
        if (line.includes('## 📚 Citations and References')) return;

        const match = line.match(/\[(\d+)\] (.*?)(?:, Section: (.*?))?(?:\(Source: (.*?)\))?$/);

        if (match) {
          let extractedContent = '';
          const citationId = match[1];
          const citationRegex = new RegExp(`.{0,150}\\[${citationId}\\].{0,50}`, 'g');
          const contentMatch = mainContent.match(citationRegex);

          if (contentMatch) {
            extractedContent = contentMatch[0].trim();
          }

          extractedCitations.push({
            id: match[1],
            title: match[2].trim(),
            section: match[3] || undefined,
            filepath: match[4] || undefined,
            content: extractedContent,
            document_name: match[2].trim(),
            file_name: match[4] ? match[4].split(/[/\\]/).pop() : undefined,
          });
        }
      });
      setCitations(normalizeCitations(extractedCitations));    
    } else {
      // Use a single refId variable for all reference types
      let refId = 1;
      
      // First check for superscript number citations with file links
      const citationText = content.toLowerCase();
      const citationsSection = citationText.indexOf("citation") > -1 ? 
                              content.substring(content.toLowerCase().indexOf("citation")) : "";
      
      // Check for citation links like "1. Northwind_Health_Plus_Benefits_Details.pdf#page=30"
      if (citationsSection) {
        const citationMatches = Array.from(citationsSection.matchAll(/(\d+)\.\s+(.*?(?:\.pdf|\.docx|\.xlsx|\.html|\.htm)(?:#page=\d+)?)/ig));
        
        for (const match of citationMatches) {
          const id = match[1];
          const filepath = match[2].trim();
          const title = filepath.split('/').pop()?.split('#')[0] || filepath;
          extractedCitations.push({
            id: id,
            title: title.trim(),
            filepath: filepath,
            content: `Citation ${id}`,
            document_name: title.trim(),
            file_name: filepath.split(/[/\\]/).pop(),
          });
          refId = Math.max(refId, parseInt(id) + 1);
        }
      }
      
      // If we found citation links, process superscript numbers in the content
      if (extractedCitations.length > 0) {
        // No need to do further processing
      } else {
        // Try to extract reference links from plain text content
        // Example: [FinOps Framework Overview](#) or [What is FOCUS?](#)
        const referenceLinks = content.match(/\[(.*?)\]\((#|\S+)\)/g) || [];
        
        for (const link of referenceLinks) {
          const titleMatch = link.match(/\[(.*?)\]/);
          const urlMatch = link.match(/\]\((.*?)\)/);
          
          if (titleMatch && titleMatch[1] && urlMatch) {
            const title = titleMatch[1];
            // Extract the URL more reliably by getting the content between () 
            const url = urlMatch[0].substring(2, urlMatch[0].length - 1);
            
            // Skip image links and non-reference links
            if (title.startsWith('!') || title.length < 3) continue;
            
            // Special handling for links with #, including links like [What is FOCUS?](#) or [FOCUS Overview](#)
            // These are common educational reference links
            if (url === "#") {
              const isEducationalLink = 
                title.toLowerCase().includes('focus') || 
                title.toLowerCase().includes('finops');
                
              extractedCitations.push({
                id: String(refId++),
                title: title.trim(),
                filepath: undefined, // No filepath for these reference links
                content: `Reference: "${title.trim()}"`,
                isEducational: isEducationalLink, // Mark as educational for special styling
              });
              continue;
            }
            
            extractedCitations.push({
              id: String(refId++),
              title: title.trim(),
              filepath: url !== "#" ? url : undefined,
              content: `Reference to "${title.trim()}"`,
            });
          }
        }      
      }
      
      // Also check for reference sections like "For more detailed insights, you can explore the following references:"
      if (extractedCitations.length === 0) {
        // Look for specific phrases that might introduce references
        const referenceSection = content.match(/(?:references|explore|insights|detailed|learn more).*?(?::|\.)([\s\S]*?)(?:$|(?=##)|(?=\n\n))/i);
        
        if (referenceSection && referenceSection[1]) {
          const sectionContent = referenceSection[1].trim();
          
          // First try to extract bullet points
          const bulletPoints = sectionContent.match(/(?:\n\s*[-•*]\s*)(.*?)(?=\n\s*[-•*]|\n\n|$)/g);
          
          if (bulletPoints && bulletPoints.length > 0) {
            // Process bullet points
            for (const point of bulletPoints) {
              const cleanPoint = point.replace(/^\n\s*[-•*]\s*/, '').trim();
              if (cleanPoint && cleanPoint.length > 5) {
                const isEducationalLink = 
                  cleanPoint.toLowerCase().includes('focus') || 
                  cleanPoint.toLowerCase().includes('finops');
                  
                extractedCitations.push({
                  id: String(refId++),
                  title: cleanPoint,
                  content: `Reference: "${cleanPoint}"`,
                  isEducational: isEducationalLink,
                });
              }
            }
          } else {
            // If no bullet points, try to split by lines or sentences
            const lines = sectionContent.split(/\n+/).filter(line => line.trim().length > 0);
            
            if (lines.length > 1) {
              for (const line of lines) {
                if (line.trim().length > 5) {
                  extractedCitations.push({
                    id: String(refId++),
                    title: line.trim(),
                    content: `Reference: "${line.trim()}"`,
                  });
                }
              }
            } else {
              // Try splitting by sentences if it's just one paragraph
              const sentences = sectionContent.split(/\.(?:\s|$)/).filter(s => s.trim().length > 0);
              for (const sentence of sentences) {
                if (sentence.trim().length > 5) {
                  extractedCitations.push({
                    id: String(refId++),
                    title: sentence.trim(),
                    content: `Reference: "${sentence.trim()}"`,
                  });
                }
              }
            }
          }
        }
      }
      
      if (extractedCitations.length > 0) {
        setCitations(normalizeCitations(extractedCitations));
      }
    }
      // Create processedText variable for citation processing
    let processedText = mainContent;
    
    // Process standard bracket citations like [1]
    processedText = processedText.replace(
      CITATION_REGEX,
      (match: string, id: string) => {
        // Always use local anchor references
        const href = `#citation-${id}`;
        return `<a href="${href}" class="ftk-citation-ref" data-citation-id="${id}" role="button" tabindex="0" aria-label="Citation ${id}">${match}</a>`;
      }
    );
    
    // Process superscript citations like ¹ (represented in text as just the number)
    // We'll find all numbers that might be citations and check if they match our citation IDs
    if (extractedCitations.length > 0) {      const citationIds = new Set(extractedCitations.map(c => c.id));
      
      // Replace all potential superscript citation numbers with linked versions
      processedText = processedText.replace(
        SUPERSCRIPT_CITATION_REGEX,
        (match: string, id: string) => {
          // Only convert to citation link if this ID exists in our citations
          if (citationIds.has(id)) {
            // Always use local anchor references for citations
            const href = `#citation-${id}`;
            return `<a href="${href}" class="ftk-citation-ref ftk-superscript" data-citation-id="${id}" role="button" tabindex="0" aria-label="Citation ${id}">${id}</a>`;
          }
          return match; // Not a citation reference, leave as is
        }
      );
    }
      // Also process any markdown links like [What is FOCUS?](#) to make them actual links
    processedText = processedText.replace(
      /\[(.*?)\]\(([^)]+)\)/g,
      (match: string, text: string, url: string) => {
        console.log('Processing Markdown link:', text, url);
        // Skip image links
        if (match.startsWith('![')) return match;
          // Special handling for "Further Reading" section links
        if (text === 'FOCUS Overview' || text === 'FOCUS Metadata Details') {
          // Find or create citation for this link
          const citationId = extractedCitations.find(c => c.title?.trim() === text.trim())?.id;
          
          if (citationId) {
            // Use local anchor reference
            return `<a href="#citation-${citationId}" class="ftk-citation-ref ftk-educational-link" data-citation-id="${citationId}"><span class="ftk-reference-icon">📖</span> ${text}</a>`;
          }
          
          // If no citation found, create a simple link that will stay in the app
          return `<a href="#" class="ftk-external-link ftk-educational-link"><span class="ftk-reference-icon">📖</span> ${text}</a>`;
        }
          
        // For empty/hash links (#), these are likely references we're tracking
        if (url === '#' || !url) {
          const citationId = extractedCitations.find(c => c.title?.trim() === text.trim())?.id;
            if (citationId) {
            // Always use local anchor references
            const href = `#citation-${citationId}`;
            
            const isEducationalLink = 
              text.toLowerCase().includes('focus') || 
              text.toLowerCase().includes('finops');
              
            if (isEducationalLink) {
              return `<a href="${href}" class="ftk-citation-ref ftk-educational-link" data-citation-id="${citationId}" role="button" tabindex="0" aria-label="Citation for ${text}"><span class="ftk-reference-icon">📖</span> ${text}</a>`;
            }
            
            return `<a href="${href}" class="ftk-citation-ref" data-citation-id="${citationId}" role="button" tabindex="0" aria-label="Citation for ${text}">${text}</a>`;
          }
        }
        
        // Handle local/relative URLs that might be incorrectly referring to localhost
        if (url.startsWith('/') || url.includes('localhost')) {
          // Try to find a citation that might match this text
          const citationId = extractedCitations.find(c => 
            c.title?.trim() === text.trim() || 
            (c.title && text && c.title.toLowerCase().includes(text.toLowerCase()))
          )?.id;
            if (citationId) {
            // Always use local anchor references
            const href = `#citation-${citationId}`;
            
            return `<a href="${href}" class="ftk-citation-ref" data-citation-id="${citationId}" role="button" tabindex="0" aria-label="Citation for ${text}">${text}</a>`;
          }
        }
        
        // Look up if there's a citation that matches this text
        const matchedCitation = extractedCitations.find(c => 
          (c.title && text && c.title.toLowerCase() === text.toLowerCase())
        );
        
        if (matchedCitation) {
          // If we found a citation that matches this text, use its local anchor
          return `<a href="#citation-${matchedCitation.id}" class="ftk-citation-ref" data-citation-id="${matchedCitation.id}" role="button" tabindex="0" aria-label="Citation for ${text}">${text}</a>`;
        }
        
        // For all other URLs, keep as just text without link to avoid external navigation
        return `<span class="ftk-external-link-disabled">${text}</span>`;
      }
    );
    
    if (onContentChange && processedContentRef.current !== processedText) {
      processedContentRef.current = processedText;
      onContentChange(processedText);
    }
  }, [content, onContentChange, providedCitations]);

  // --- Inline citation rendering ---
  // Always process [n] and superscript numbers as inline clickable links
  let displayContent = processedContentRef.current || content;
  if (citations.length > 0) {
    // Replace [n] with superscript clickable links
    displayContent = displayContent.replace(
      CITATION_REGEX,
      (_match, id) => {
        const href = `#citation-${id}`;
        return `<sup><a href="${href}" class="ftk-citation-inline" data-citation-id="${id}" role="button" tabindex="0" aria-label="Citation ${id}">${id}</a></sup>`;
      }
    );
    // Replace bare numbers (superscript style) with clickable links if they match a citation
    const citationIds = new Set(citations.map(c => c.id));
    displayContent = displayContent.replace(
      SUPERSCRIPT_CITATION_REGEX,
      (_match, id) => {
        if (citationIds.has(id)) {
          const href = `#citation-${id}`;
          return `<sup><a href="${href}" class="ftk-citation-inline" data-citation-id="${id}" role="button" tabindex="0" aria-label="Citation ${id}">${id}</a></sup>`;
        }
        return _match;
      }
    );
  }
  // --- Render ---
  console.log('Rendering with citations:', citations.length, citations);
  
  return (
    <div className="ftk-citation-handler">
      <div dangerouslySetInnerHTML={{ __html: displayContent }} />      {citations.length > 0 ? (        <div className="ftk-citation-card-list" aria-label="Citations and References" role="region" style={{
          marginTop: '30px', 
          borderTop: '1px solid #e0e0e0', 
          paddingTop: '24px',
          background: 'linear-gradient(to bottom, rgba(240,245,255,0.5), transparent)',
          borderRadius: '10px',
          position: 'relative'
        }}>
          <h3 style={{
            marginBottom: '16px', 
            fontSize: '1.25em', 
            color: '#333',
            display: 'flex',
            alignItems: 'center',
            gap: '10px'
          }}>
            <span style={{fontSize: '1.2em', lineHeight: '1em'}}>📚</span> 
            <span>Citations and References {citations.length > 1 ? `(${citations.length})` : ''}</span>
          </h3>
          <div className="ftk-citation-cards-container" style={{
            display: 'flex',
            flexDirection: 'column',
            gap: '14px'
          }}>
            {citations.map((citation) => (              <div
                key={citation.id}
                id={`citation-${citation.id}`}
                className="ftk-citation-card"
                style={{
                  padding: '14px', 
                  margin: '0', 
                  borderRadius: '8px',
                  border: '1px solid #e0e0e0',
                  boxShadow: '0 2px 8px rgba(0,0,0,0.07)',
                  backgroundColor: '#fcfcfc',
                  transition: 'all 0.2s ease',
                  position: 'relative',
                  cursor: 'default'
                }}
                aria-label={`Citation ${citation.id}: ${citation.title}`}
                tabIndex={0}
                onClick={() => {
                  // Add highlighting effect on click
                  const el = document.getElementById(`citation-${citation.id}`);
                  if (el) {
                    el.style.backgroundColor = '#f0f7ff';
                    setTimeout(() => {
                      el.style.backgroundColor = '#fcfcfc';
                    }, 300);
                  }
                }}
              >                <div className="ftk-citation-pill-number" style={{
                  display: 'inline-flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  marginBottom: '10px',
                  backgroundColor: '#0078d4',
                  color: 'white',
                  borderRadius: '50%',
                  width: '26px',
                  height: '26px',
                  textAlign: 'center',
                  fontWeight: 'bold',
                  fontSize: '0.9em',
                  boxShadow: '0 2px 4px rgba(0,120,212,0.2)'
                }}>{citation.id}</div>                <div className="ftk-citation-card-title" style={{
                  fontWeight: 600, 
                  marginBottom: '6px',
                  fontSize: '1.05em',
                  color: '#222'
                }}>{citation.title}</div>
                {citation.section && (
                  <div className="ftk-citation-card-section" style={{
                    marginBottom: '4px', 
                    color: '#0078d4', 
                    fontSize: '0.95em',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '5px'
                  }}>
                    <span style={{fontWeight: 500}}>Section:</span> {citation.section}
                  </div>
                )}                <div className="ftk-citation-card-docname" style={{
                  color: '#444', 
                  fontSize: '0.93em', 
                  marginTop: '4px', 
                  fontStyle: 'italic'
                }} title={citation.document_name}>
                  {citation.document_name}
                </div>
                {citation.file_name && (
                  <div className="ftk-citation-card-author" style={{
                    fontSize: '0.85em', 
                    color: '#666',
                    marginTop: '3px',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '4px'
                  }} title={citation.file_name}>
                    <span style={{color: '#888', fontSize: '0.9em'}}>📄</span>
                    {citation.file_name}
                  </div>
                )}
              </div>
            ))}
          </div>
        </div>
      ) : (
        // Show debugging info if no citations are displayed
        process.env.NODE_ENV === 'development' && (
          <div style={{marginTop: '20px', padding: '10px', border: '1px dashed red', color: 'red', fontSize: '12px'}}>
            No citations found in content. Debug info: foundCitations={String(citations.length > 0)}
          </div>
        )
      )}
    </div>
  );
};

// Helper to normalize citation data for both structured and legacy/fallback formats
function normalizeCitations(rawCitations: CitationData[]): CitationData[] {
  console.log('Normalizing citations:', rawCitations.length);
  
  return rawCitations.map((c) => {
    // Always ensure document_name and file_name fields
    let document_name = c.document_name || c.title || '';
    let file_name = '';
    
    // Enhanced file extraction from various sources
    if (c.filepath) {
      file_name = c.filepath.split(/[/\\]/).pop() || '';
      // If document_name is a path, use just the file name
      if (!c.document_name && (document_name.includes('/') || document_name.includes('\\'))) {
        document_name = file_name;
      }
    } else if (c.file_name) {
      // Direct file_name field takes precedence
      file_name = c.file_name;
    } else {
      // Try different methods to extract file information
      
      // Method 1: If title or document_name looks like a file with extension
      if (document_name.match(/\.(pdf|docx|xlsx|html?|md|json|txt|csv)$/i)) {
        file_name = document_name;
      }
      
      // Method 2: Look for file patterns in the document name
      const filePattern = document_name.match(/(\w+[-_]?\w+\.(pdf|docx|xlsx|html?|md|json|txt|csv))/i);
      if (filePattern) {
        file_name = filePattern[0];
      }
      
      // Method 3: Check if content contains file references
      if (c.content) {
        const contentFilePattern = c.content.match(/(\w+[-_]?\w+\.(pdf|docx|xlsx|html?|md|json|txt|csv))/i);
        if (contentFilePattern && !file_name) {
          file_name = contentFilePattern[0];
        }
      }
    }
    
    // Clean up document_name if it's excessively long
    if (document_name.length > 100) {
      document_name = document_name.substring(0, 97) + '...';
    }
    
    // If we still don't have a reasonable document name, try to create one
    if (!document_name || document_name.length < 3) {
      document_name = file_name || `Citation ${c.id}`;
    }
    
    console.log(`Citation ${c.id} normalized:`, { document_name, file_name });
    
    return {
      ...c,
      document_name,
      file_name,
    };
  });
}

// Debug helper function to log citation details
function logCitationDetails(citation: CitationData, index: number): void {
  console.log(`Citation ${index + 1} details:`, {
    id: citation.id,
    title: citation.title,
    document_name: citation.document_name,
    file_name: citation.file_name,
    section: citation.section,
    filepath: citation.filepath,
    isEducational: citation.isEducational,
    chunkId: citation.chunkId
  });
}

export default CitationHandler;
