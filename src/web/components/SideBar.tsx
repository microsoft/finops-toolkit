import { useState } from 'react';
import { Link } from 'react-router-dom';
import {
  FluentProvider,
  makeStyles,
  Button,
  tokens,
} from "@fluentui/react-components";
import {
  HomeRegular,
  HomeFilled,
  DataUsageRegular,
  DataUsageFilled,
  BookOpenRegular,
  BookOpenFilled,
  CodeRegular,
  CodeFilled,
  DatabaseRegular,
  DatabaseFilled,
  CloudRegular,
  CloudFilled,
  LearningAppRegular,
  LearningAppFilled,
  PeopleRegular,
  PeopleFilled,
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
  { name: 'Home', icon: <HomeRegular />, filledIcon: <HomeFilled />, route: '/' },
  { name: 'FinOps Hubs', icon: <DataUsageRegular />, filledIcon: <DataUsageFilled />, route: '/hubs' },
  { name: 'Power BI', icon: <BookOpenRegular />, filledIcon: <BookOpenFilled />, route: '/power-bi' },
  { name: 'PowerShell', icon: <CodeRegular />, filledIcon: <CodeFilled />, route: '/powershell' },
  { name: 'Bicep Modules', icon: <DatabaseRegular />, filledIcon: <DatabaseFilled />, route: '/bicep-registry' },
  { name: 'Open Data', icon: <CloudRegular />, filledIcon: <CloudFilled />, route: '/open-data' },
  {
    name: 'Learning',
    icon: <LearningAppRegular />,
    filledIcon: <LearningAppFilled />,
    route: 'https://learn.microsoft.com/cloud-computing/finops/toolkit/finops-toolkit-overview',
    external: true,
  },
  { name: 'Contributors', icon: <PeopleRegular />, filledIcon: <PeopleFilled />, route: '/contributors' },
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
