import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { SamplePage } from '../SamplePage';

// Mock dependencies
jest.mock('../../components/SideBar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);

describe('SamplePage', () => {
  it('renders the layout with TopMenuBar and Sidebar', () => {
    // Render the SamplePage inside a BrowserRouter (for routing context)
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

    // Check if the main content area is rendered
    const mainContent = screen.getByTestId('main-content');
    expect(mainContent).toBeInTheDocument();

    // Check if the heading is rendered
    const heading = screen.getByRole('heading', { name: /samplepage/i });
    expect(heading).toBeInTheDocument();
  });

  it('applies correct styles to the root container', () => {
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
      width: '100%',
      overflowX: 'hidden',
      backgroundColor: '#f4f6f8',
    });
  });

  it('renders and styles the main content area correctly', () => {
    render(
      <BrowserRouter>
        <SamplePage />
      </BrowserRouter>
    );

    const mainContent = screen.getByTestId('main-content');
    expect(mainContent).toHaveStyle({
      flexGrow: 1,
      display: 'flex',
      flexDirection: 'column',
      overflowY: 'auto',
      overflowX: 'hidden',
      backgroundColor: '#ffffff',
    });
  });
});
