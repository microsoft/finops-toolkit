// filepath: c:\_repos\finops-toolkit-1\src\finley\frontend\src\components\CitationHandler.tsx
import React, { useState, useEffect, useRef, useCallback } from 'react';
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

    // Log for debugging
    console.log('CitationHandler processing content with citations:', providedCitations?.length);
    if (providedCitations && providedCitations.length > 0) {
      console.log('Citation details:', providedCitations.map(c => ({
        id: c.id, 
        title: c.title || c.document_name,
        section: c.section,
        filepath: c.filepath,
        chunkId: c.chunkId
      })));    }

    // Add a helper function to process markdown links to create citation cards
    if (providedCitations && providedCitations.length > 0) {
      const formattedCitations = convertToCitationData(providedCitations as Citation[]);
      setCitations(formattedCitations);

      let processedText = content;      processedText = processedText.replace(
        CITATION_REGEX,
        (match, id) => {
          // Always use local anchor references for citations
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

    const citationMatch = content.match(CITATION_SECTION_REGEX);
    const extractedCitations: CitationData[] = [];
    let mainContent = content;
    
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
          });
        }
      });

      setCitations(extractedCitations);    
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
        setCitations(extractedCitations);
      }
    }
      // Create processedText variable for citation processing
    let processedText = content;
    
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
            // Always use local anchor references for all citations
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

  // Set the initial state of all citations to be expanded
  const [expandedCitations, setExpandedCitations] = useState<Record<string, boolean>>({});
  
  // Auto-expand all citations on initial render for visibility
  useEffect(() => {
    if (citations.length > 0) {
      const expanded: Record<string, boolean> = {};
      citations.forEach(citation => {
        expanded[citation.id] = true;  // Set all to expanded by default
      });
      setExpandedCitations(expanded);
    }
  }, [citations]);
  
  // Method to handle citation link clicks
  const handleCitationLinkClick = useCallback((id: string, e?: React.MouseEvent | MouseEvent) => {
    if (e) e.preventDefault();
    
    // Expand the citation if it's not already expanded
    setExpandedCitations(prev => ({
      ...prev,
      [id]: true
    }));
    
    // Find the citation element and highlight it
    const citationEl = document.getElementById(`citation-${id}`);
    if (citationEl) {
      // Remove active class from all citations
      document.querySelectorAll('.ftk-citation-card').forEach(el =>
        el.classList.remove('ftk-citation-active')
      );
      
      // Add active and highlight classes to the clicked citation
      citationEl.classList.add('ftk-citation-active', 'ftk-citation-highlight');
      
      // Pulse animation for all reference links that point to this citation
      document.querySelectorAll(`[data-citation-id="${id}"]`).forEach(el => {
        el.classList.add('ftk-reference-clicked');
        setTimeout(() => {
          el.classList.remove('ftk-reference-clicked');
        }, 500);
      });
      
      // Scroll to the citation
      citationEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
      
      // Remove highlight class after animation completes
      setTimeout(() => {
        citationEl.classList.remove('ftk-citation-highlight');
      }, 1500);
    }
  }, []);

  // Install a global handler for citation clicks
  useEffect(() => {
    if (processedContentRef.current) {
      if (typeof window !== 'undefined' && !window.handleCitationClick) {
        window.handleCitationClick = handleCitationLinkClick;
      }
        // Process the content on citation link click - add click listeners to all citation references
      setTimeout(() => {
        const linkElements = document.querySelectorAll('.ftk-citation-ref');
        linkElements.forEach(element => {          element.addEventListener('click', (e) => {
            const id = element.getAttribute('data-citation-id');
            if (id) {
              // Always prevent default navigation and use local reference
              e.preventDefault();
              handleCitationLinkClick(id, e as MouseEvent);
            }
          });
        });
      }, 100); // Small delay to ensure DOM is ready
    }
    
    // Cleanup
    return () => {
      if (typeof window !== 'undefined' && window.handleCitationClick === handleCitationLinkClick) {
        // Only clear if it's still our handler
        window.handleCitationClick = () => {}; // Empty handler
      }
    };
  }, [handleCitationLinkClick]);
  
  const toggleCitation = (id: string) => {
    setExpandedCitations(prev => ({
      ...prev,
      [id]: !prev[id]
    }));
  };

  return (
    <div className="ftk-citation-handler">
      <div dangerouslySetInnerHTML={{ __html: processedContentRef.current || content }} />

      {citations.length > 0 && (
        <div className="ftk-citation-links">
          <h3>📚 Citations and References</h3>
          {/* Debug info */}
          <small style={{ color: '#666', marginBottom: '8px', display: 'block' }}>
            {citations.length} citation(s) available
          </small>
          <div className="ftk-citation-cards">
            {citations.map((citation) => (
              <div 
                key={citation.id} 
                id={`citation-${citation.id}`} 
                className={`ftk-citation-card ${expandedCitations[citation.id] ? 'ftk-citation-card-expanded' : ''} ${citation.isEducational ? 'ftk-educational-citation' : ''}`}
              >
                <div 
                  className="ftk-citation-card-header" 
                  onClick={() => toggleCitation(citation.id)}
                >
                  <span>
                    {citation.isEducational && <span className="ftk-reference-icon">📖</span>}
                    [{citation.id}] {citation.title}
                  </span>
                </div>                <div className="ftk-citation-card-details">
                  {citation.section && <div className="ftk-citation-section"><strong>Section:</strong> {citation.section}</div>}                  {/* Show citation information - no external links */}
                  {citation.filepath && !citation.filepath.startsWith("http") && (
                    <>
                      <div className="ftk-citation-section"><strong>File:</strong> {citation.filepath.split(/[/\\]/).pop()}</div>
                      <div className="ftk-citation-section"><strong>Path:</strong> {citation.filepath}</div>
                    </>
                  )}
                  
                  {/* If it was an external resource, just show the title but no link */}
                  {citation.filepath && citation.filepath.startsWith("http") && (
                    <div className="ftk-citation-section">
                      <strong>Resource:</strong> <span className="ftk-resource-title">{citation.title}</span>
                    </div>
                  )}
                  
                  {/* Display chunk ID if available */}
                  {citation.chunkId && <div className="ftk-citation-section"><strong>Chunk ID:</strong> {citation.chunkId}</div>}
                  {citation.content && <div className="ftk-citation-content"><p>"{citation.content}"</p></div>}                  {/* Only show View Source for local files, not for external resources */}
                  {citation.filepath && !citation.filepath.startsWith("http") && (
                    <div className="ftk-citation-source">
                      <span className="ftk-source-link ftk-file-source">
                        Source: {citation.filepath.split(/[/\\]/).pop()}
                      </span>
                    </div>
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
};

export default CitationHandler;
