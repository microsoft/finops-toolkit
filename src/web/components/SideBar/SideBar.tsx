import { useState } from 'react';
import { Link } from 'react-router-dom';
import { Button, Text } from '@fluentui/react-components';
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
  PanelLeftExpandRegular,
  PanelLeftContractRegular,
} from '@fluentui/react-icons';
import './SideBar.css';

const menuItems = [
  { name: 'Home', icon: <Home24Regular />, filledIcon: <Home24Filled />, route: '/' },
  { name: 'FinOps hubs', icon: <DataUsage24Regular />, filledIcon: <DataUsage24Filled />, route: '/hubs' },
  { name: 'Power BI', icon: <BookOpen24Regular />, filledIcon: <BookOpen24Filled />, route: '/power-bi' },
  { name: 'FinOps workbooks', icon: <BookOpen24Regular />, filledIcon: <BookOpen24Filled />, route: '/workbooks' },
  { name: 'Optimization Engine', icon: <BookOpen24Regular />, filledIcon: <BookOpen24Filled />, route: '/optimization-engine' },
  { name: 'PowerShell', icon: <Code24Regular />, filledIcon: <Code24Filled />, route: '/powershell' },
  { name: 'Bicep modules', icon: <Database24Regular />, filledIcon: <Database24Filled />, route: '/bicep-registry' },
  { name: 'Open data', icon: <Cloud24Regular />, filledIcon: <Cloud24Filled />, route: '/open-data' },
  {
    name: 'FinOps guide',
    icon: <LearningApp24Regular />,
    filledIcon: <LearningApp24Filled />,
    route: 'https://learn.microsoft.com/cloud-computing/finops/implementing-finops-guide',
    external: true,
  },
];

const SideBar = () => {
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

  const toggleSidebar = () => {
    setIsCollapsed(!isCollapsed);
  };

  return (
    <div className={`ftk-sidebar ${isCollapsed ? 'ftk-collapsed' : 'ftk-expanded'}`}>
      <Button
        appearance='subtle'
        icon={isCollapsed ? <PanelLeftExpandRegular /> : <PanelLeftContractRegular />}
        className='ftk-sidebar-toggle'
        onClick={toggleSidebar}
        aria-label={isCollapsed ? 'Expand Sidebar' : 'Collapse Sidebar'}
      />
      <div className='ftk-sidebar-menu'>
        {menuItems.map((item, index) => (
          <div
            key={index}
            onMouseEnter={() => setHoveredIndex(index)}
            onMouseLeave={() => setHoveredIndex(null)}
          >
            {item.external ? (
              <a href={item.route} target='_blank' rel='noopener noreferrer' className='ftk-sidebar-item'>
                <div className='ftk-sidebar-icon'>
                  {hoveredIndex === index ? item.filledIcon : item.icon}
                </div>
                {!isCollapsed && <Text>{item.name}</Text>}
              </a>
            ) : (
              <Link to={item.route} className='ftk-sidebar-item'>
                <div className='ftk-sidebar-icon'>
                  {hoveredIndex === index ? item.filledIcon : item.icon}
                </div>
                {!isCollapsed && <Text>{item.name}</Text>}
              </Link>
            )}
          </div>
        ))}
      </div>
    </div>
  );
};

export default SideBar;
