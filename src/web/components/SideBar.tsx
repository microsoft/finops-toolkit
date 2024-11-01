import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  FluentProvider,
  makeStyles,
  Button,
  tokens,
} from "@fluentui/react-components";
import {
  Home24Regular,
  Home24Filled,
  DataUsage24Regular,
  DataUsage24Filled,
  BookOpen24Regular,
  BookOpen24Filled,
  Code24Regular,
  Code24Filled,
  Database24Regular,
  Database24Filled,
  Cloud24Regular,
  Cloud24Filled,
  LearningApp24Regular,
  LearningApp24Filled,
  People24Regular,
  People24Filled,
  PanelLeftExpandRegular,
  PanelLeftContractRegular,
} from "@fluentui/react-icons";

const useStyles = makeStyles({
    sidebar: {
      minHeight: '100vh',
      backgroundColor: '#f4f6f8',
      display: 'flex',
      flexDirection: 'column',
      position: 'relative',
      transition: 'width 0.2s ease',
      paddingTop: '40px',
      paddingRight: '18px',
      paddingLeft: '16px',
      paddingBottom: '16px',
      marginTop: '0',
    },
    collapsed: {
      width: '80px',
    },
    expanded: {
      width: '216px',
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
      borderRadius: '6px',
      position: 'relative',
      transition: 'background-color 0.2s ease, color 0.2s ease',
      '&:hover': {
        backgroundColor: '#E6E6E6', // Updated neutral grey background on hover
        color: tokens.colorNeutralForeground2BrandHover,
      },
      '&:hover $icon': {
        color: tokens.colorNeutralForeground2BrandHover,
      },
      '&::before': {
        content: '""',
        position: 'absolute',
        left: '2px',
        top: '22px',
        transform: 'translateY(-50%)',
        width: '4px',
        height: '18px',
        backgroundColor: 'transparent',
        borderRadius: '2px',
        transition: 'background-color 0.1s ease',
      },
      '&:hover::before': {
        backgroundColor: tokens.colorNeutralForeground3BrandHover,
      },
    },
    icon: {
      marginRight: '10px',
      transition: 'color 0.1s ease',
    },
  });
  

const menuItems = [
  { name: 'Home', icon: <Home24Regular />, filledIcon: <Home24Filled />, route: '/' },
  { name: 'FinOps Hubs', icon: <DataUsage24Regular />, filledIcon: <DataUsage24Filled />, route: '/hubs' },
  { name: 'Power BI', icon: <BookOpen24Regular />, filledIcon: <BookOpen24Filled />, route: '/power-bi' },
  { name: 'PowerShell', icon: <Code24Regular />, filledIcon: <Code24Filled />, route: '/powershell' },
  { name: 'Bicep Modules', icon: <Database24Regular />, filledIcon: <Database24Filled />, route: '/bicep-registry' },
  { name: 'Open Data', icon: <Cloud24Regular />, filledIcon: <Cloud24Filled />, route: '/open-data' },
  {
    name: 'Learning',
    icon: <LearningApp24Regular />,
    filledIcon: <LearningApp24Filled />,
    route: 'https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview',
    external: true,
  },
  { name: 'Contributors', icon: <People24Regular />, filledIcon: <People24Filled />, route: '/contributors' },
];

function SideBar() {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null); // Explicitly typed to accept number or null
  const classes = useStyles();

  const toggleSidebar = () => {
    setIsCollapsed(!isCollapsed);
  };

  return (
    <FluentProvider>
      <div className={`${classes.sidebar} ${isCollapsed ? classes.collapsed : classes.expanded}`}>
        <Button
          appearance="subtle"
          icon={isCollapsed ? <PanelLeftExpandRegular /> : <PanelLeftContractRegular />}
          className={classes.toggleButton}
          onClick={toggleSidebar}
        />
        {menuItems.map((item, index) => (
          <div
            key={index}
            onMouseEnter={() => setHoveredIndex(index)}
            onMouseLeave={() => setHoveredIndex(null)}
          >
            {item.external ? (
              <a href={item.route} target="_blank" rel="noopener noreferrer" className={classes.menuItem}>
                <div className={classes.icon}>
                  {hoveredIndex === index ? item.filledIcon : item.icon}
                </div>
                {!isCollapsed && <span>{item.name}</span>}
              </a>
            ) : (
              <Link to={item.route} className={classes.menuItem}>
                <div className={classes.icon}>
                  {hoveredIndex === index ? item.filledIcon : item.icon}
                </div>
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
