import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom'; // Ensure routing context
import { SamplePage } from '../SamplePage';

// Adjust the paths as needed to match your project structure
jest.mock('../../components/Sidebar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);

describe('SamplePage', () => {
  it('renders the SamplePage layout correctly', () => {
    render(
      <BrowserRouter>
        <SamplePage />
      </BrowserRouter>
    );

    // Check if TopMenuBar is rendered
    const topMenuBar = screen.getByTestId('top-menu-bar');
    expect(topMenuBar).toBeInTheDocument();

    // Check if Sidebar is rendered
    const sidebar = screen.getByTestId('sidebar');
    expect(sidebar).toBeInTheDocument();

    // Check if the main content area is rendered with the heading "SamplePage"
    const mainContent = screen.getByRole('heading', { name: /samplepage/i });
    expect(mainContent).toBeInTheDocument();
  });

  it('applies correct layout and styling properties', () => {
    render(
      <BrowserRouter>
        <SamplePage />
      </BrowserRouter>
    );

    // Verify the root container's layout styles
    const rootContainer = screen.getByTestId('sample-page-root');
    expect(rootContainer).toHaveStyle({
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      overflowX: 'hidden',
      backgroundColor: '#f4f6f8',
    });

    // Verify the sidebar and main content area layout
    const sidebar = screen.getByTestId('sidebar');
    expect(sidebar.parentElement).toHaveStyle({ display: 'flex', flexGrow: 1 });

    const mainContentContainer = screen.getByTestId('main-content');
    expect(mainContentContainer).toHaveStyle({
      flexGrow: 1,
      display: 'flex',
      flexDirection: 'column',
      backgroundColor: '#ffffff',
    });
  });
});
