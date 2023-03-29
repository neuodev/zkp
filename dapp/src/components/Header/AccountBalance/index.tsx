// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

import * as React from 'react';

import {InputAdornment, Box} from '@mui/material';
import {formatCurrency} from 'lib/format';
import {useAppSelector} from 'redux/hooks';
import {chainBalanceSelector} from 'redux/slices/wallet/chain-balance';

import {AccountBalanceProps} from './AccountBalance.interface';

import './styles.scss';

export default function AccountBalance(props: AccountBalanceProps) {
    const chainBalance = useAppSelector(chainBalanceSelector);

    return (
        <Box className="account-balance">
            {formatCurrency(chainBalance, {decimals: 3}) || '-'}
            <InputAdornment position="end" className="currency-symbol">
                <span>{props.networkSymbol || '-'}</span>
            </InputAdornment>
        </Box>
    );
}
