import '@testing-library/jest-dom';
import { render, screen, fireEvent } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import SideBar from '../SideBar/SideBar';

// Helper function to render with Router
const renderWithRouter = (component: React.ReactNode) => {
  return render(<BrowserRouter>{component}</BrowserRouter>);
};

describe('SideBar Component', () => {
  it('should toggle the filled icon when menu item is hovered', () => {
    renderWithRouter(<SideBar />);

    // Find the Home menu item
    const homeMenuItem = screen.getByText(/Home/i).closest('a');
    expect(homeMenuItem).toBeInTheDocument();

    // Find the icon inside the menu item
    const homeIconContainer = homeMenuItem?.querySelector('.ftk-sidebar-icon');
    expect(homeIconContainer).toBeInTheDocument();

    // Get initial icon before hover
    const initialIcon = homeIconContainer?.querySelector('svg')?.outerHTML;

    // Simulate mouse enter (hover)
    fireEvent.mouseEnter(homeMenuItem!);

    // Check if icon changed on hover
    const hoveredIcon = homeIconContainer?.querySelector('svg')?.outerHTML;
    expect(hoveredIcon).not.toEqual(initialIcon);

    // Simulate mouse leave
    fireEvent.mouseLeave(homeMenuItem!);

    // Icon should revert back to original
    const revertedIcon = homeIconContainer?.querySelector('svg')?.outerHTML;
    expect(revertedIcon).toEqual(initialIcon);
  });

  it('should render internal links correctly', () => {
    renderWithRouter(<SideBar />);

    // Check if internal links render with correct hrefs
    expect(screen.getByText(/Home/i).closest('a')).toHaveAttribute('href', '/');
    expect(screen.getByText(/FinOps hubs/i).closest('a')).toHaveAttribute('href', '/hubs');
    expect(screen.getByText(/Power BI/i).closest('a')).toHaveAttribute('href', '/power-bi');
  });

  it('should render external links with correct attributes', () => {
    renderWithRouter(<SideBar />);

    // Check for the external FinOps Guide link
    const learningLink = screen.getByText(/FinOps guide/i);
    expect(learningLink.closest('a')).toHaveAttribute(
      'href',
      'https://learn.microsoft.com/cloud-computing/finops/implementing-finops-guide'
    );
    expect(learningLink.closest('a')).toHaveAttribute('target', '_blank');
    expect(learningLink.closest('a')).toHaveAttribute('rel', 'noopener noreferrer');
  });

  it('should collapse and expand sidebar when toggle button is clicked', () => {
    renderWithRouter(<SideBar />);

    // Sidebar should initially be expanded
    expect(screen.getByText(/Home/i)).toBeInTheDocument();

    // Find the toggle button
    const toggleButton = screen.getByRole('button', { name: /Collapse Sidebar/i });
    fireEvent.click(toggleButton); // Collapse

    // Home text should disappear
    expect(screen.queryByText(/Home/i)).not.toBeInTheDocument();

    // Click again to expand
    fireEvent.click(toggleButton);

    // Home text should be visible again
    expect(screen.getByText(/Home/i)).toBeInTheDocument();
  });
});
