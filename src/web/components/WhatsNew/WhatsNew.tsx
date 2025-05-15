import { Card, CardHeader, Text, Button, Body1, Caption1, tokens, makeStyles } from '@fluentui/react-components';

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
      '& img': {
        // Apply the transform to the image on card hover
        transform: 'translateX(10%)',
      },
    },
    '@media (min-width: 1200px)': {
      height: '248px',
    },
    '@media (max-width: 1199px)': {},
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
    '@media (max-width: 767px)': {},
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

  let version = '0.10';
  let month = 'April 2025';
  let tool: { name: string; update?: string; image?: string } = {
    summary: {
      name: 'FinOps toolkit',
      update:
        'April introduces FinOps hubs support for Microsoft Fabric; support for Azure Gov and Azure China in FinOps hubs and Power BI reports; FinOps Framework 2025 updates; and, many additional small fixes, improvements, and documentation updates across the board.',
      // TODO: Add custom image -- image: 'finopsbg.png',
    },
  }['summary'];

  return (
    tool.update && (
      <Card className={styles.styledCard}>
        <div className={styles.contentWrapper}>
          <div className={styles.leftSide}>
            <CardHeader
              header={
                <Text weight="semibold" size={500}>
                  What's new in {month} <span className="ftk-version">{version}</span>
                </Text>
              }
              description={tool.update}
            />
            <div className={styles.buttonWrapper}>
              <Button appearance="secondary" as="a" href="https://learn.microsoft.com/cloud-computing/finops/toolkit/changelog" target="_blank" className={styles.smallButton}>
                See all changes
              </Button>
              {/* <Caption1>Last updated: February 02, 2024</Caption1> */}
            </div>
          </div>

          <div className={styles.rightSide}>
            <img src={tool.image ?? 'finopsbg.png'} alt="" className={styles.slidingImage} />
          </div>
        </div>
      </Card>
    )
  );
};

export default WhatsNew;
