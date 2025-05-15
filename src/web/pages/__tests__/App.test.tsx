import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { HomePage } from '../HomePage';

jest.mock('../../components/SideBar/SideBar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);
jest.mock('../../components/HomeBanner/HomeBanner', () => () => <div data-testid="homeBanner">Kick start your FinOps efforts</div>);

describe('App Routing', () => {
  it('should render SamplePage for the root path', () => {
    render(
      <MemoryRouter initialEntries={['/']} future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/" element={<HomePage />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
    expect(screen.getByTestId('sidebar')).toBeInTheDocument();
    expect(screen.getByTestId('main-content')).toBeInTheDocument();
    expect(screen.getByTestId('homeBanner')).toBeInTheDocument();
  });

  it('should render SamplePage for the /tools path', () => {
    render(
      <MemoryRouter initialEntries={['/tools']} future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/tools" element={<HomePage />} />
        </Routes>
      </MemoryRouter>,
    );

    expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
    expect(screen.getByTestId('sidebar')).toBeInTheDocument();
    expect(screen.getByTestId('main-content')).toBeInTheDocument();
    expect(screen.getByTestId('homeBanner')).toBeInTheDocument();
  });
});
