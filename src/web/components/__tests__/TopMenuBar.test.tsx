import { render, screen } from '@testing-library/react';
import TopMenuBar from '../TopMenuBar/TopMenuBar';
import React from 'react';

describe('TopMenuBar', () => {
    it('should render the logo and title', () => {
        render(<TopMenuBar />);

        // Check if the logo is rendered
        const logo = screen.getByAltText('Microsoft Logo');
        expect(logo).toBeInTheDocument();

        // Check if the title text is rendered
        const title = screen.getByText('FinOps toolkit');
        expect(title).toBeInTheDocument();
    });

    it('should render a divider between the logo and title', () => {
        render(<TopMenuBar />);

        // Check that the divider is present
        const divider = screen.getByRole('separator');
        expect(divider).toBeInTheDocument();
    });

    it('renders with accessible elements', () => {
        render(<TopMenuBar />);

        // Check if the logo has appropriate alt text
        const logo = screen.getByAltText('Microsoft Logo');
        expect(logo).toHaveAttribute('alt', 'Microsoft Logo');

        // Verify that the title text exists and contains the expected text
        const title = screen.getByText('FinOps toolkit');
        expect(title).toBeInTheDocument();
    });

    it('matches the snapshot', () => {
        const { asFragment } = render(<TopMenuBar />);
        expect(asFragment()).toMatchSnapshot();
    });
});
