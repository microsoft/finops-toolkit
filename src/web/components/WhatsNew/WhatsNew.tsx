import { Card, CardHeader, Text, Button, Body1, Caption1, tokens, makeStyles } from "@fluentui/react-components";

const useStyles = makeStyles({
    styledCard: {
        display: 'flex',
        flexDirection: 'row',
        marginTop: '40px',
        marginLeft: '36px',
        marginRight: '36px',
        borderRadius: '12px',
        overflow: 'hidden',
        boxShadow: '0 2px 8px rgba(0, 0, 0, 0.1)',
        transition: 'box-shadow 0.3s ease-out',
        ':hover': {
            '& img': { // Apply the transform to the image on card hover
                transform: 'translateX(10%)',
            },
        },
        '@media (min-width: 1200px)': {
            height: '248px',
        },
        '@media (max-width: 1199px)': {

        },
    },
    contentWrapper: {
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        width: '100%',
        backgroundImage: 'url(finopstoolkitbg.png)',
        backgroundRepeat: 'repeat',
        backgroundSize: 'auto',
        backgroundPosition: 'top left',
        '@media (max-width: 767px)': {
            flexDirection: 'column',
            justifyContent: 'center',
        },
    },
    leftSide: {
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
        padding: '24px',
        '@media (max-width: 767px)': {
            textAlign: 'center',
            alignItems: 'center',
            padding: '16px',
        },
    },
    rightSide: {
        flex: 1,
        overflow: 'hidden',
        position: 'relative',
        '@media (max-width: 767px)': {
            width: '100%',
            height: 'auto',
        },
    },
    slidingImage: {
        width: '100%',
        height: '220px',
        borderRadius: '24px',
        objectFit: 'cover',
        transform: 'translateX(20%)', // Initial position
        transition: 'transform 0.2s ease-out', // Smooth transition
        '@media (max-width: 767px)': {

        },
    },
    buttonWrapper: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'flex-start',
        marginTop: '16px',
        '@media (max-width: 767px)': {
            alignItems: 'center',
        },
    },
    smallButton: {
        padding: '8px 16px',
        border: `1px solid ${tokens.colorNeutralStroke1}`,
        borderRadius: tokens.borderRadiusMedium,
        backgroundColor: tokens.colorNeutralBackground1,
        color: tokens.colorNeutralForeground1,
        textDecoration: 'none',
        cursor: 'pointer',
        ':hover': {
            backgroundColor: tokens.colorNeutralBackground1Hover,
            color: tokens.colorNeutralForeground1Hover,
        },
        ':visited': {
            color: tokens.colorNeutralForeground1,
        },
        '@media (max-width: 767px)': {
            fontSize: '14px',
        },
    },
});

const WhatsNew = () => {
    const styles = useStyles();

    return (
        <Card className={styles.styledCard}>
            <div className={styles.contentWrapper}>
                <div className={styles.leftSide}>
                    <CardHeader
                        header={
                            <Text weight="semibold" size={500}>
                                What's new in FinOps toolkit 0.8
                            </Text>
                        }
                        description={
                            <Body1>
                                The February 2025 release of FinOps Hubs v0.8 introduces a new Data Explorer dashboard template, enhanced KQL functions, improved networking defaults, documentation updates, and performance fixes, while deprecating older KQL functions for better efficiency.
                            </Body1>
                        }
                    />
                    <div className={styles.buttonWrapper}>
                        <Button
                            appearance="secondary"
                            as="a"
                            href="https://github.com/microsoft/finops-toolkit/releases/tag/v0.8"
                            target="_blank"
                            rel="noopener noreferrer"
                            className={styles.smallButton}
                        >
                            See all changes
                        </Button>
                        <Caption1>Last updated: February 02, 2024</Caption1>
                    </div>
                </div>

                <div className={styles.rightSide}>
                    <img
                        src="costmgmtfinopsbg.png"
                        alt="Cost Management Finops Banner"
                        className={styles.slidingImage}
                    />
                </div>
            </div>
        </Card>
    );
};

export default WhatsNew;
