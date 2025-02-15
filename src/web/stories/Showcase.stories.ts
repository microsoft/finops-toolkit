import type { StoryObj } from '@storybook/react';

import Showcase from '../components/Showcase/Showcase';

export default {
  title: 'Components/Showcase',
  component: Showcase,
};

type Story = StoryObj<typeof Showcase>;

export const Default: Story = {
  args: {},
};
