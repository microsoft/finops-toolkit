import { render, screen } from '@testing-library/react';
import HomePage from '../HomePage';
import { BrowserRouter as Router } from 'react-router-dom';
import '@testing-library/jest-dom';

describe('HomePage', () => {
  it('should render the FinOps Toolkit header', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const headerElement = screen.getByText(/FinOps toolkit - Kick start your FinOps efforts/i);
    expect(headerElement).toBeInTheDocument(); // Check for the correct header text
  });

  it('should have a link to available tools', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const toolsLink = screen.getByText(/Get the tools/i);
    expect(toolsLink).toBeInTheDocument();
    expect(toolsLink).toHaveAttribute('href', '/tools');
  });

  it('should have a feedback link', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    // Use getAllByText to find all "Give feedback" links
    const feedbackLinks = screen.getAllByText(/💜 Give feedback/i);
    
    // Check the first instance (or choose the one based on href)
    const feedbackLink = feedbackLinks[0]; // or use feedbackLinks.find(link => link.getAttribute('href') === 'https://aka.ms/ftk/feedback');
    
    expect(feedbackLink).toBeInTheDocument();
    expect(feedbackLink).toHaveAttribute('href', 'https://aka.ms/ftk/feedback');
  });

  it('should have a link to the roadmap', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const roadmapLink = screen.getByText(/Discover what's next/i);
    expect(roadmapLink).toBeInTheDocument();
    expect(roadmapLink).toHaveAttribute('href', 'https://github.com/microsoft/finops-toolkit/milestones');
  });
});
