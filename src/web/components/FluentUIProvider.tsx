import React from 'react';
import { FluentProvider, webLightTheme } from '@fluentui/react-components';

interface Props {
  children: React.ReactNode;
}

function FluentUIProvider({ children }: Props) {
  return (
    <FluentProvider theme={webLightTheme}>
      {children}
    </FluentProvider>
  );
}

export default FluentUIProvider;
