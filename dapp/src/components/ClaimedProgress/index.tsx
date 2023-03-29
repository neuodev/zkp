// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import React from 'react';

import {Box, LinearProgress, Typography} from '@mui/material';

import './styles.scss';

interface ClaimedProgressTypes {
    claimed: number;
    total: number;
}

function formatNumber(v: number): string {
    if (v >= 1e6) {
        return (v / 1e6).toFixed(0) + 'm';
    }
    if (v >= 1e3) {
        return (v / 1e3).toFixed(0) + 'k';
    }

    return v.toFixed(0);
}

export default function ClaimedProgress(props: ClaimedProgressTypes) {
    const {claimed, total} = props;
    const percentage = total !== 0 ? (claimed / total) * 100 : 0;
    const claimedValue = `${formatNumber(claimed)} / ${formatNumber(
        total,
    )} zZKP claimed (~${Math.ceil(percentage)}%)`;

    return (
        <Box
            className="claimed-progress-container"
            data-testid="claimed-progress_claimed-progress_container"
        >
            <Box className="claimed-progress">
                <Typography className="title">
                    Advanced Staking Rewards
                </Typography>
                <Box className="progress-holder">
                    <LinearProgress
                        className="progress"
                        variant="determinate"
                        value={percentage}
                    />
                </Box>
                <Typography
                    className="claimed-value"
                    data-testid="claimed-progress_claimed-progress_value"
                >
                    {claimedValue}
                </Typography>
            </Box>
        </Box>
    );
}
