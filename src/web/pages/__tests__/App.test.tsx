import { render, screen } from '@testing-library/react';
import App from '../App';

it('should render the FinOpsPage component for the root path', () => {
    render(<App />);
    
    // Check for the title text in the Banner component
    const bannerTitle = screen.getByText(/Kick start your FinOps efforts/i);
    expect(bannerTitle).toBeInTheDocument();
});
