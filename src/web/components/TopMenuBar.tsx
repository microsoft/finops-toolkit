import { Text } from '@fluentui/react-components';
import styled from 'styled-components';

function TopMenuBar() {


// Return the top menu bar with the FinOps toolkit logo

  return (
    <FullWidthContainer>
      <StyledCommandBar>
        <LogoTextContainer>
          <Logo src="logo-windows.png" alt="Microsoft Logo" />
          <TextContainer>
            <Text size={300} weight="medium">FinOps toolkit</Text>
          </TextContainer>
        </LogoTextContainer>

      </StyledCommandBar>
    </FullWidthContainer>
  );
}


// Styled components for layout and customization
const StyledCommandBar = styled.div`
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  background-color: #f4f6f8;
  overflow-x: hidden;

  /* Media Query for responsiveness */
  @media (max-width: 768px) {
    flex-direction: column;
    align-items: center;  /* Center align all items */
  }
`;

const LogoTextContainer = styled.div`
  display: flex;
  align-items: center;
  margin: 8px;

  @media (max-width: 768px) {
    display: flex;
    flex-direction: row;
    align-items: center;
    
    margin: 8px;
  }
`;

const Logo = styled.img`
  width: 24px;
  height: 24px;
  margin-right: 8px;
`;

const TextContainer = styled.div`
  font-size: 12px;
  color: #333;

  @media (max-width: 768px) {
    text-align: center;
  }
`;

// Ensure the top menu bar takes the full viewport width
const FullWidthContainer = styled.div`
  width: 100vw;
  margin: 0;
  padding: 0;
  height: 40px;
`;

export default TopMenuBar;
