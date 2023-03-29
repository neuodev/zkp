// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import React from 'react';

import {Box, Typography} from '@mui/material';
import xIcon from 'images/x-icon.svg';
import {useAppDispatch, useAppSelector} from 'redux/hooks';
import {
    acknowledgedNotificationSelector,
    acknowledgeNotification,
} from 'redux/slices/ui/acknowledged-notifications';

import {MessageAlertProps} from './MessageAlert.interface';

import './styles.scss';

const MessageAlert = (props: MessageAlertProps) => {
    const acknowledgedNotification = useAppSelector(
        acknowledgedNotificationSelector(props.notificationOwner),
    );

    const dispatch = useAppDispatch();

    return (
        <>
            {!acknowledgedNotification && (
                <Box className="message-alert-container">
                    <Box className="alert-box">
                        <img
                            src={xIcon}
                            alt="close"
                            className="close-icon"
                            onClick={() =>
                                dispatch(
                                    acknowledgeNotification,
                                    props.notificationOwner,
                                )
                            }
                        />
                        <Box className="text-box">
                            <Typography className="title">
                                {props.title}
                            </Typography>
                            <Typography className="body">
                                {props.body}
                            </Typography>
                        </Box>
                    </Box>
                </Box>
            )}
        </>
    );
};

export default MessageAlert;
