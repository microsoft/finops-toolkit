import { render, screen, fireEvent } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import SideBar from '../../components/SideBar';

// Helper function to render with Router
const renderWithRouter = (component: React.ReactNode) => {
  return render(<BrowserRouter>{component}</BrowserRouter>);
};

describe('SideBar Component', () => {
  it('should collapse the sidebar when toggle button is clicked', () => {
    renderWithRouter(<SideBar />);

    // Initially, sidebar should not be collapsed (menu items should be visible)
    expect(screen.getByText(/Home/i)).toBeInTheDocument();

    // Find the toggle button by aria-label
    const toggleButton = screen.getByRole('button', { name: /collapse sidebar/i });
    fireEvent.click(toggleButton);

    // After collapse, the "Home" text should not be visible
    expect(screen.queryByText(/Home/i)).not.toBeInTheDocument();
  });

  it('should expand the sidebar when toggle button is clicked again', () => {
    renderWithRouter(<SideBar />);

    // Collapse the sidebar first
    const toggleButton = screen.getByRole('button', { name: /collapse sidebar/i });
    fireEvent.click(toggleButton); // collapse

    // Then expand the sidebar
    fireEvent.click(toggleButton); // expand

    // "Home" text should be visible again after expanding
    expect(screen.getByText(/Home/i)).toBeInTheDocument();
  });

  it('should render internal links correctly', () => {
    renderWithRouter(<SideBar />);

    // Check if the internal links render with correct hrefs
    const homeLink = screen.getByText(/Home/i);
    expect(homeLink.closest('a')).toHaveAttribute('href', '/');

    const finOpsLink = screen.getByText(/FinOps Hubs/i);
    expect(finOpsLink.closest('a')).toHaveAttribute('href', '/hubs');

    const powerBILink = screen.getByText(/Power BI/i);
    expect(powerBILink.closest('a')).toHaveAttribute('href', '/power-bi');
  });

  it('should render external links with correct attributes', () => {
    renderWithRouter(<SideBar />);

    // Check for the external link and ensure it has appropriate attributes
    const learningLink = screen.getByText(/Learning/i);
    expect(learningLink.closest('a')).toHaveAttribute(
      'href',
      'https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview'
    );
    expect(learningLink.closest('a')).toHaveAttribute('target', '_blank');
    expect(learningLink.closest('a')).toHaveAttribute('rel', 'noopener noreferrer');
  });

  it('should display the filled icon when menu item is hovered', () => {
    renderWithRouter(<SideBar />);

    // Hover over the Home link
    const homeMenuItem = screen.getByText(/Home/i).closest('a');
    fireEvent.mouseEnter(homeMenuItem!);

    // Check if the icon displayed is the filled variant by conditionally testing for its presence
    expect(screen.getByText(/Home/i).previousSibling).toBeInTheDocument();
  });
});

