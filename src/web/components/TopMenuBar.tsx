import { Text, makeStyles, FluentProvider, Image, Divider } from '@fluentui/react-components';

const useStyles = makeStyles({
  fullWidthContainer: {
    width: '100vw',
    height: '40px',
    marginTop: '8px',
    padding: 0,
  },
  commandBar: {
    display: 'flex',
    justifyContent: 'flex-start',
    alignItems: 'center',
    width: '100%',
    backgroundColor: '#f4f6f8',
    overflowX: 'hidden',
    '@media (max-width: 768px)': {
      flexDirection: 'column',
      alignItems: 'center',
    },
  },
  logoTextContainer: {
    display: 'flex',
    alignItems: 'center',
    margin: '8px',
    '@media (max-width: 768px)': {
      flexDirection: 'row',
      alignItems: 'center',
    },
  },
  logo: {
    width: '24px',
    height: '24px',
    marginRight: '8px',
  },
  divider: {
    height: '20px',
    margin: '0 8px',
  },
  textContainer: {
    fontSize: '12px',
    color: '#333',
    '@media (max-width: 768px)': {
      textAlign: 'center',
    },
  },
});

function TopMenuBar() {
  const classes = useStyles();

  return (
    <FluentProvider>
      <div className={classes.fullWidthContainer}>
        <div className={classes.commandBar}>
          <div className={classes.logoTextContainer}>
            <Image src="logo-windows.png" alt="Microsoft Logo" className={classes.logo} />
            <div className={classes.textContainer}>
              <Text size={300} weight="medium">
                FinOps toolkit
              </Text>
            </div>
            <Divider vertical className={classes.divider} />
          </div>
        </div>
      </div>
    </FluentProvider>
  );
}

export default TopMenuBar;
