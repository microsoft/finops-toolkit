import { render, screen } from '@testing-library/react';
import TopMenuBar from '../TopMenuBar/TopMenuBar';
import React from 'react';

describe('TopMenuBar', () => {
    it('renders the logo with correct alt text', () => {
        render(<TopMenuBar />);

        const logo = screen.getByRole('img', { name: /Microsoft Logo/i });
        expect(logo).toBeInTheDocument();
        expect(logo).toHaveAttribute('alt', 'Microsoft Logo');
    });

    it('renders the title with correct text', () => {
        render(<TopMenuBar />);

        const title = screen.getByText(/FinOps Toolkit/i);
        expect(title).toBeInTheDocument();
    });

    it('renders an accessible divider', () => {
        render(<TopMenuBar />);

        const divider = screen.getByRole('separator');
        expect(divider).toBeInTheDocument();
    });

    it('ensures all key elements are visible and accessible', () => {
        render(<TopMenuBar />);

        const logo = screen.getByRole('img', { name: /Microsoft Logo/i });
        expect(logo).toBeVisible();

        const title = screen.getByText(/FinOps Toolkit/i);
        expect(title).toBeVisible();

        const divider = screen.getByRole('separator');
        expect(divider).toBeVisible();
    });
});
