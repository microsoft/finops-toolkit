import { render, screen } from '@testing-library/react';
import HomePage from '../HomePage';
import { BrowserRouter as Router } from 'react-router-dom';
import '@testing-library/jest-dom';
import { within } from '@testing-library/react';

describe('HomePage', () => {
  it('should render the FinOps Toolkit header', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const headerElement = screen.getByText(/FinOps toolkit - Kick start your FinOps efforts/i);
    expect(headerElement).toBeInTheDocument();
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

  it('should have a feedback link in the header', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const feedbackLink = screen.getAllByText(/💜 Give feedback/i)[0];
    expect(feedbackLink).toBeInTheDocument();
    expect(feedbackLink).toHaveAttribute('href', 'https://aka.ms/ftk/feedback');
  });

  it('should have a feedback link in the available tools section', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const feedbackLink = screen.getAllByText(/💜 Give feedback/i)[1];
    expect(feedbackLink).toBeInTheDocument();
    expect(feedbackLink).toHaveAttribute('href', 'https://aka.ms/ftk/feedback');
  });

  it('should have a roadmap link', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const roadmapLink = screen.getByText(/Discover what's next/i);
    expect(roadmapLink).toBeInTheDocument();
    expect(roadmapLink).toHaveAttribute('href', 'https://github.com/microsoft/finops-toolkit/milestones');
  });

  it('should have a link to join the conversation', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const conversationLink = screen.getByText(/Join the conversation/i);
    expect(conversationLink).toBeInTheDocument();
    expect(conversationLink).toHaveAttribute('href', 'https://github.com/microsoft/finops-toolkit/discussions');
  });

  it('should have a link to contribute in the Get Involved section', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );
  
    const getInvolvedSection = screen.getByRole('heading', { name: /Get Involved/i }).closest('section');
    expect(getInvolvedSection).not.toBeNull();  // Ensure section exists
  
    const contributeLink = within(getInvolvedSection!).getByText(/Learn how to contribute/i);
  
    expect(contributeLink).toBeInTheDocument();
    expect(contributeLink).toHaveAttribute('href', 'https://github.com/microsoft/finops-toolkit/blob/main/CONTRIBUTING.md');
  });
  
  

  it('should have a link to the changelog', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const changelogLink = screen.getByText(/Explore the changelog/i);
    expect(changelogLink).toBeInTheDocument();
    expect(changelogLink).toHaveAttribute('href', './_resources/changelog.md');
  });

  it('should have a link to browse the commit history', () => {
    render(
      <Router>
        <HomePage />
      </Router>
    );

    const commitHistoryLink = screen.getByText(/Browse the commit history/i);
    expect(commitHistoryLink).toBeInTheDocument();
    expect(commitHistoryLink).toHaveAttribute('href', 'https://github.com/microsoft/finops-toolkit/commits/main');
  });
});
