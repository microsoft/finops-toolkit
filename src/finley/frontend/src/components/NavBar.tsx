// src/components/NavBar.tsx
import { makeStyles, tokens } from "@fluentui/react-components";
import { Link } from "react-router-dom";
import { Button } from "@fluentui/react-components";
import { Home24Regular, Chat24Regular } from "@fluentui/react-icons";

const useStyles = makeStyles({
  nav: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "1rem",
    backgroundColor: "#f9f9f9",
    borderBottom: `1px solid ${tokens.colorNeutralStroke2}`,
  },
  logo: {
    fontWeight: 600,
    fontSize: "1.25rem",
    display: "flex",
    alignItems: "center",
    gap: "0.5rem",
  },
  links: {
    display: "flex",
    gap: "0.75rem",
    fontWeight: 500,
  },
  buttonLink: {
    textDecoration: "none",
    display: "flex",
    alignItems: "center",
  },
  navButton: {
    display: "flex",
    alignItems: "center",
    gap: "0.5rem",
    padding: "0.5rem 0.75rem",
    borderRadius: "6px",
    fontSize: "0.9375rem",
    fontWeight: 500,
    ":hover": {
      backgroundColor: tokens.colorNeutralBackground3Hover,
    },
  },
});

export default function NavBar() {
  const styles = useStyles();
  return (
    <header className={styles.nav}>
      <div className={styles.logo}>🤖 Finley</div>
      <nav className={styles.links}>
        <Link to="/" className={styles.buttonLink}>
          <Button icon={<Home24Regular />} appearance="transparent" className={styles.navButton}>
            Home
          </Button>
        </Link>
        <Link to="/chat" className={styles.buttonLink}>
          <Button icon={<Chat24Regular />} appearance="transparent" className={styles.navButton}>
            Chat
          </Button>
        </Link>
      </nav>
    </header>
  );
}
