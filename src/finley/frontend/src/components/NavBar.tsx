// src/components/NavBar.tsx
import { makeStyles, tokens } from "@fluentui/react-components";
import { Link } from "react-router-dom";

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
  },
  links: {
    display: "flex",
    gap: "1.5rem",
    fontWeight: 500,
  },
});

export default function NavBar() {
  const styles = useStyles();
  return (
    <header className={styles.nav}>
      <div className={styles.logo}>🤖 Finley</div>
      <nav className={styles.links}>
        <Link to="/">Home</Link>
        <Link to="/chat">Chat</Link>
      </nav>
    </header>
  );
}
