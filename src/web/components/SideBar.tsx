import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  FluentProvider,
  makeStyles,
  Button,
} from "@fluentui/react-components";
import {
  Home24Regular,
  DataUsage24Regular,
  BookOpen24Regular,
  Code24Regular,
  Database24Regular,
  Cloud24Regular,
  LearningApp24Regular,
  People24Regular,
  ChevronRight24Regular,
  ChevronLeft24Regular
} from "@fluentui/react-icons";

// Styles for the sidebar using Fluent UI's `makeStyles`
const useStyles = makeStyles({
  sidebar: {
    minHeight: '100vh',
    backgroundColor: '#f4f6f8',
    display: 'flex',
    flexDirection: 'column',
    position: 'relative',
    transition: 'width 0.2s ease',
    paddingTop: '44px',
  },
  collapsed: {
    width: '80px',
  },
  expanded: {
    width: '200px',
  },
  toggleButton: {
    position: 'absolute',
    top: '10px',
    right: '8px',
  },
  menuItem: {
    display: 'flex',
    alignItems: 'center',
    padding: '10px 12px',
    color: '#333',
    textDecoration: 'none',
    '&:hover': {
      backgroundColor: '#e2e8f0',
      borderRadius: '8px',
    },
  },
  icon: {
    marginRight: '10px',
  },
});

// Menu items with Fluent v2 icons and routes
const menuItems = [
  { name: 'Home', icon: <Home24Regular />, route: '/' },
  { name: 'FinOps Hubs', icon: <DataUsage24Regular />, route: '/hubs' },
  { name: 'Power BI', icon: <BookOpen24Regular />, route: '/power-bi' },
  { name: 'PowerShell', icon: <Code24Regular />, route: '/powershell' },
  { name: 'Bicep Modules', icon: <Database24Regular />, route: '/bicep-registry' },
  { name: 'Open Data', icon: <Cloud24Regular />, route: '/open-data' },
  {
    name: 'Learning',
    icon: <LearningApp24Regular />,
    route: 'https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview',
    external: true,
  },
  { name: 'Contributors', icon: <People24Regular />, route: '/contributors' },
];

const SideBar = () => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const classes = useStyles();

  const toggleSidebar = () => {
    setIsCollapsed(!isCollapsed);
  };

  return (
    <FluentProvider>
      <div className={`${classes.sidebar} ${isCollapsed ? classes.collapsed : classes.expanded}`}>
        <Button
          appearance="subtle"
          icon={isCollapsed ? <ChevronRight24Regular /> : <ChevronLeft24Regular />}
          className={classes.toggleButton}
          onClick={toggleSidebar}
        />
        {menuItems.map((item, index) => (
          <div key={index}>
            {item.external ? (
              <a href={item.route} target="_blank" rel="noopener noreferrer" className={classes.menuItem}>
                <div className={classes.icon}>{item.icon}</div>
                {!isCollapsed && <span>{item.name}</span>}
              </a>
            ) : (
              <Link to={item.route} className={classes.menuItem}>
                <div className={classes.icon}>{item.icon}</div>
                {!isCollapsed && <span>{item.name}</span>}
              </Link>
            )}
          </div>
        ))}
      </div>
    </FluentProvider>
  );
};

export default SideBar;
