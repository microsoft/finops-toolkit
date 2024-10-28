import { useState } from 'react';
import styled from 'styled-components';
import { Link } from 'react-router-dom';  // Import the Link component
import { FaHome, FaChartBar, FaBook, FaCode, FaDatabase, FaCloud, FaUserGraduate, FaUsers } from 'react-icons/fa';

// Menu items with their respective icons and routes
const menuItems = [
    { name: 'Home', icon: <FaHome />, route: '/' },
    { name: 'FinOps hubs', icon: <FaChartBar />, route: '/hubs' },
    { name: 'Power BI', icon: <FaBook />, route: '/power-bi' },
    { name: 'PowerShell', icon: <FaCode />, route: '/powershell' },
    { name: 'Bicep modules', icon: <FaDatabase />, route: '/bicep-registry' },
    { name: 'Open data', icon: <FaCloud />, route: '/open-data' },
    { name: 'Learning', icon: <FaUserGraduate />, external: true, route: 'https://learn.microsoft.com/en-us/cloud-computing/finops/toolkit/finops-toolkit-overview' }, // External link
    { name: 'Contributors', icon: <FaUsers />, route: '/contributors' },
];

const Sidebar = () => {
  const [isCollapsed, setIsCollapsed] = useState(false);

  const toggleSidebar = () => {
    setIsCollapsed(!isCollapsed);
  };

  return (
    <SidebarContainer $isCollapsed={isCollapsed}>
      <ToggleIcon onClick={toggleSidebar}>
        {isCollapsed ? (
          <img src="sidebar-right-svgrepo-com.png" alt="Expand Sidebar" width={20} />
        ) : (
          <img src="sidebar-left-svgrepo-com.png" alt="Collapse Sidebar" width={20} />
        )}
      </ToggleIcon>

      {/* Map through menuItems to render each with icon, text, and routing */}
      {menuItems.map((item, index) => (
        <MenuItem key={index} $isCollapsed={isCollapsed}>
          {item.external ? (
            <a
              href={item.route}
              target="_blank"
              rel="noopener noreferrer"
              style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}
            >
              <IconWrapper $isCollapsed={isCollapsed}>{item.icon}</IconWrapper>
              {!isCollapsed && <MenuText>{item.name}</MenuText>}
            </a>
          ) : (
            <Link
              to={item.route}
              style={{ display: 'flex', alignItems: 'center', textDecoration: 'none', color: 'inherit' }}
            >
              <IconWrapper $isCollapsed={isCollapsed}>{item.icon}</IconWrapper>
              {!isCollapsed && <MenuText>{item.name}</MenuText>}
            </Link>
          )}
        </MenuItem>
      ))}
    </SidebarContainer>
  );
};

// Sidebar container styling using `$isCollapsed` as a transient prop
const SidebarContainer = styled.div<{ $isCollapsed: boolean }>`
  min-height: 100vh;
  width: ${({ $isCollapsed }) => ($isCollapsed ? '80px' : '200px')};
  background-color: #f4f6f8;
  padding: 20px;
  display: flex;
  flex-direction: column;
  transition: width 0.2s ease;
  position: relative;
`;
  
  // Toggle icon for collapsing the sidebar
  const ToggleIcon = styled.div`
    position: absolute;
    top: 6px;
    right: 8px;
    cursor: pointer;
  `;
  
// Menu item styling using `$isCollapsed` as a transient prop
const MenuItem = styled.div<{ $isCollapsed: boolean }>`
  display: flex;
  align-items: center;
  padding: ${({ $isCollapsed }) => ($isCollapsed ? '10px 8px' : '10px 12px')};
  cursor: pointer;
  margin-top: 8px;
  margin-left: ${({ $isCollapsed }) => ($isCollapsed ? '0px' : '10px')};
  transition: background-color 0.1s ease, padding 0.1s ease;

  &:hover {
    background-color: #e2e8f0;
    border-radius: 12px;
  }
`;

  
// Icon wrapper for menu items using `$isCollapsed` as a transient prop
const IconWrapper = styled.div<{ $isCollapsed: boolean }>`
  margin-right: ${({ $isCollapsed }) => ($isCollapsed ? '0' : '10px')};
  display: flex;
  justify-content: center;
  align-items: center;

  svg {
    width: 20px;
    height: 20px;
  }
`;
  

// Menu text styling
const MenuText = styled.span`
  font-size: 16px;
  font-weight: 500;
  color: #333;
`;

export default Sidebar;
