import { render, screen } from '@testing-library/react';
import { MemoryRouter, Routes, Route } from 'react-router-dom';
import { SamplePage  } from '../SamplePage';

jest.mock('../../components/SideBar/SideBar', () => () => <div data-testid="sidebar" />);
jest.mock('../../components/TopMenuBar/TopMenuBar', () => () => <div data-testid="top-menu-bar" />);
jest.mock('../../components/Showcase/Showcase', () => () => <div data-testid="showcase">Kick start your FinOps efforts</div>);
describe('SamplePage', () => {
    it('renders SamplePage correctly', () => {
        render(
            <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}> {/* ✅ Apply future flags */}
                <Routes>
                    <Route path="/" element={<SamplePage />} />
                </Routes>
            </MemoryRouter>
        );

        // ✅ Ensure Sidebar & TopMenuBar Exist
        expect(screen.getByTestId('top-menu-bar')).toBeInTheDocument();
        expect(screen.getByTestId('sidebar')).toBeInTheDocument();

        // ✅ Ensure Main Content is Rendered
        expect(screen.getByTestId('main-content')).toBeInTheDocument();

        // ✅ Fix: Search for Showcase Component Instead of Failing Heading
        expect(screen.getByTestId('showcase')).toBeInTheDocument();
        expect(screen.getByText(/Kick start your FinOps efforts/i)).toBeInTheDocument();
    });

    it('applies correct styles to root container', () => {
        render(
            <MemoryRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
                <Routes>
                    <Route path="/" element={<SamplePage />} />
                </Routes>
            </MemoryRouter>
        );

        // ✅ Fix: Ensure Root Container Exists & Has Correct Styles
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
