import { Text, Image, Divider } from '@fluentui/react-components';
import './TopMenuBar.css';

const TopMenuBar = () => {
    return (
        <div className="fullWidthContainer">
            <div className="commandBar">
                <div className="logoTextContainer">
                    <Image src="logo-windows.png" alt="Microsoft Logo" className="logo" />
                    <div className="textContainer">
                        <Text size={300} weight="medium">
                            FinOps toolkit
                        </Text>
                    </div>
                    <Divider vertical className="divider" />
                </div>
            </div>
        </div>
    );
}

export default TopMenuBar;
