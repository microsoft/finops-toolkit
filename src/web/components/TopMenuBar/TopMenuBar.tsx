import { Text, Image, Divider } from "@fluentui/react-components";
import "./TopMenuBar.css";
const TopMenuBar = () => {
  return (
    <header className="ftk-topmenubar">
      <div className="ftk-commandbar">
        <div className="ftk-logo-section">
          <Image src="logo-windows.png" alt="Microsoft Logo" className="ftk-logo" />
          <Text weight="medium">FinOps Toolkit</Text>
          <Divider vertical className="ftk-divider" />
        </div>
      </div>
    </header>
  );
};

export default TopMenuBar;
