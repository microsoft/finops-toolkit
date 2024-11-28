import { render, screen } from '@testing-library/react';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import FinOpsHubsPage from '../FinOpsHubsPage';
import {SamplePage} from '../SamplePage';

describe('App routing', () => {
  it('should render SamplePage for the root path', () => {
    render(
      <MemoryRouter initialEntries={['/']}>
        <Routes>
          <Route path="/" element={<SamplePage />} />
        </Routes>
      </MemoryRouter>
    );

    const sampleContent = screen.getByText(/SamplePage/i);
    expect(sampleContent).toBeInTheDocument();
  });

  it('should render FinOpsHubsPage for the /hubs path', () => {
    render(
      <MemoryRouter initialEntries={['/hubs']}>
        <Routes>
          <Route path="/hubs" element={<FinOpsHubsPage />} />
        </Routes>
      </MemoryRouter>
    );

    // Use getAllByText and check the first element if there are multiple matches
    const hubsHeadings = screen.getAllByText(/FinOps Hubs/i);
    expect(hubsHeadings[0]).toBeInTheDocument();

    // Check for specific content in the page to ensure the correct page is rendered
    const hubsContent = screen.getByText(/Open, extensible, and scalable cost governance for the enterprise/i);
    expect(hubsContent).toBeInTheDocument();
  });

  it('should render SamplePage for the /tools path', () => {
    render(
      <MemoryRouter initialEntries={['/tools']}>
        <Routes>
          <Route path="/tools" element={<SamplePage />} />
        </Routes>
      </MemoryRouter>
    );

    const sampleContent = screen.getByText(/SamplePage/i);
    expect(sampleContent).toBeInTheDocument();
  });

});
