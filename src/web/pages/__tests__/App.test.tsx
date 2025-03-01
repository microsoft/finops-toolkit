import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { SamplePage } from '../SamplePage';

jest.mock('../../components/SideBar/SideBar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);
jest.mock('../../components/Showcase/Showcase', () => () => <div data-testid="showcase">Kick start your FinOps efforts</div>);

describe('App Routing', () => {
  it('should render SamplePage for the root path', () => {
    render(
      <MemoryRouter initialEntries={['/']} future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/" element={<SamplePage />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
    expect(screen.getByTestId('sidebar')).toBeInTheDocument();
    expect(screen.getByTestId('main-content')).toBeInTheDocument();
    expect(screen.getByTestId('showcase')).toBeInTheDocument();
    expect(screen.getByText(/Welcome to Sample Page/i)).toBeInTheDocument();
  });

  it('should render SamplePage for the /tools path', () => {
    render(
      <MemoryRouter initialEntries={['/tools']} future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
        <Routes>
          <Route path="/tools" element={<SamplePage />} />
        </Routes>
      </MemoryRouter>
    );

    expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
    expect(screen.getByTestId('sidebar')).toBeInTheDocument();
    expect(screen.getByTestId('main-content')).toBeInTheDocument();
    expect(screen.getByTestId('showcase')).toBeInTheDocument();
    expect(screen.getByText(/Welcome to Sample Page/i)).toBeInTheDocument();
  });
});
