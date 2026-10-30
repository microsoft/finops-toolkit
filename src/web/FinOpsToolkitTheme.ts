const ftk: BrandVariants = {
  10: '#030205',
  20: '#1A1423',
  30: '#2A1E3E',
  40: '#382755',
  50: '#46316D',
  60: '#553A86',
  70: '#6444A0',
  80: '#734FB4',
  90: '#815FBC',
  100: '#8F6FC3',
  110: '#9C7ECA',
  120: '#A98FD1',
  130: '#B69FD8',
  140: '#C3AFDF',
  150: '#D0C0E6',
  160: '#DDD1ED',
};

const lightTheme: Theme = {
  ...createLightTheme(ftk),
};

const darkTheme: Theme = {
  ...createDarkTheme(ftk),
};

darkTheme.colorBrandForeground1 = ftk[110];
darkTheme.colorBrandForeground2 = ftk[120];
