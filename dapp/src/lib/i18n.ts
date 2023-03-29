// SPDX-License-Identifier: BUSL-1.1
// SPDX-FileCopyrightText: Copyright 2021-22 Panther Ventures Limited Gibraltar

// For testing only!
let localeOverride: string | undefined;
export function _setLocale(locale: string) {
    localeOverride = locale;
}

export function getLocale(): string {
    return (
        localeOverride ||
        navigator.language ||
        new Intl.NumberFormat().resolvedOptions().locale
    );
}

export function getDecimalSeparator(): string {
    const n = 1.1;
    return n.toLocaleString(getLocale()).substring(1, 2);
}
