import { render, screen } from '@testing-library/react';
import TopMenuBar from '../../components/TopMenuBar';

describe('TopMenuBar', () => {
  it('should render the logo and title', () => {
    render(<TopMenuBar />);

    // Logo should be rendered
    const logo = screen.getByAltText('Microsoft Logo');
    expect(logo).toBeInTheDocument();

    // Title should be rendered
    const title = screen.getByText('FinOps toolkit');
    expect(title).toBeInTheDocument();
  });


});