import { render, screen, fireEvent } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom'; // For Link routing
import Sidebar from '../../components/Sidebar';

// Helper function to render with Router
const renderWithRouter = (component: React.ReactNode) => {
  return render(<BrowserRouter>{component}</BrowserRouter>);
};

describe('Sidebar', () => {
  it('should collapse the sidebar when toggle button is clicked', () => {
    renderWithRouter(<Sidebar />);

    // Initially, sidebar should not be collapsed (menu items should be visible)
    expect(screen.getByText(/Home/i)).toBeInTheDocument();

    // Find the toggle button by alt text
    const toggleButton = screen.getByAltText(/Collapse Sidebar/i);

    // Simulate click to collapse the sidebar
    fireEvent.click(toggleButton);

    // After collapse, the menu items should no longer be visible
    expect(screen.queryByText(/Home/i)).not.toBeInTheDocument();
  });

  it('should expand the sidebar when toggle button is clicked again', () => {
    renderWithRouter(<Sidebar />);

    // Find the toggle button by alt text and simulate clicks to collapse and then expand
    const toggleButton = screen.getByAltText(/Collapse Sidebar/i);
    fireEvent.click(toggleButton); // collapse
    fireEvent.click(toggleButton); // expand

    // Menu text should be visible again after expanding
    expect(screen.getByText(/Home/i)).toBeInTheDocument();
  });

  it('should render internal links correctly', () => {
    renderWithRouter(<Sidebar />);

    // Check for internal link rendering
    const homeLink = screen.getByText(/Home/i);
    expect(homeLink.closest('a')).toHaveAttribute('href', '/');

    const finOpsLink = screen.getByText(/FinOps hubs/i);
    expect(finOpsLink.closest('a')).toHaveAttribute('href', '/hubs');

    const powerBILink = screen.getByText(/Power BI/i);
    expect(powerBILink.closest('a')).toHaveAttribute('href', '/power-bi');
  });

  it('should render external link with correct attributes', () => {
    renderWithRouter(<Sidebar />);

    // Check for external link rendering and attributes
    const learningLink = screen.getByText(/Learning/i);
    expect(learningLink.closest('a')).toHaveAttribute('href', 'https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/finops-toolkit-overview');
    expect(learningLink.closest('a')).toHaveAttribute('target', '_blank');
    expect(learningLink.closest('a')).toHaveAttribute('rel', 'noopener noreferrer');
  });
});
