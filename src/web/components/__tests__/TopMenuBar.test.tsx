import { render, screen } from "@testing-library/react";
import TopMenuBar from "../TopMenuBar/TopMenuBar";
import React from "react";

describe("TopMenuBar", () => {
    it("renders the logo with correct alt text", () => {
        render(<TopMenuBar />);

        // Ensure the logo is present and has correct attributes
        const logo = screen.getByRole("img", { name: /Microsoft Logo/i });
        expect(logo).toBeInTheDocument();
        expect(logo).toHaveAttribute("alt", "Microsoft Logo");
    });

    it("renders the title with correct text", () => {
        render(<TopMenuBar />);

        // Ensure the title text is present
        const title = screen.getByText(/FinOps Toolkit/i);
        expect(title).toBeInTheDocument();
    });

    it("renders an accessible divider", () => {
        render(<TopMenuBar />);

        // Ensure the divider is present and accessible
        const divider = screen.getByRole("separator");
        expect(divider).toBeInTheDocument();
    });

    it("ensures all key elements are visible and accessible", () => {
        render(<TopMenuBar />);

        // Logo check
        const logo = screen.getByRole("img", { name: /Microsoft Logo/i });
        expect(logo).toBeVisible();

        // Title check
        const title = screen.getByText(/FinOps Toolkit/i);
        expect(title).toBeVisible();

        // Divider check
        const divider = screen.getByRole("separator");
        expect(divider).toBeVisible();
    });
});
