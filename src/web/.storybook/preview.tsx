import React from 'react';
import { teamsLightTheme, FluentProvider } from '@fluentui/react-components';
import type { Preview } from '@storybook/react';
import type { Decorator } from '@storybook/react';

const withFluentProvider: Decorator = (Story) => (
  <FluentProvider theme={teamsLightTheme}>
    <Story />
  </FluentProvider>
);

const preview: Preview = {
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    layout: 'fullscreen',
  },
  decorators: [withFluentProvider],
};

export default preview;
