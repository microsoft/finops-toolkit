import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { HomePage } from '../HomePage';

jest.mock('../../components/SideBar/SideBar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);
jest.mock('../../components/HomeBanner/HomeBanner', () => () => <div data-testid="homeBanner">Kick start your FinOps efforts</div>);
describe('HomePage', () => {
  it('renders HomePage correctly', () => {
    render(
      <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
    expect(screen.getByTestId('sidebar')).toBeInTheDocument();

    expect(screen.getByTestId('main-content')).toBeInTheDocument();

    expect(screen.getByTestId('homeBanner')).toBeInTheDocument();
    expect(screen.getByText(/Kick start your FinOps efforts/i)).toBeInTheDocument();
  });

  it('applies correct styles to root container', () => {
    render(
      <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
        </Routes>
      </MemoryRouter>,
    );

    const rootContainer = screen.getByTestId('sample-page-root');
    expect(rootContainer).toHaveStyle({
      display: 'flex',
      flexDirection: 'column',
      height: '100vh',
      overflowX: 'hidden',
      backgroundColor: 'var(--colorNeutralBackground1)',
    });
  });
});
