# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

BeforeAll {
    $functionRoot = (Get-Item -Path $PSScriptRoot).Parent.Parent.FullName
    $functionName = Split-Path -Path ($PSCommandPath.Replace('.Tests.ps1', '.ps1')) -Leaf
    $functionPath = Get-ChildItem -Path $functionRoot -Recurse -Include $functionName
    if (-not $functionPath)
    {
        throw "Cannot find associated function for test: '$PSCommandPath'."
    }

    . $functionPath
}

Describe 'New-Directory' {
    BeforeAll {
        Mock -CommandName 'New-Item'
        $path = 'TestDrive:\FakeDirectory'
    }

    It 'Should not create a directory if it exists' {
        Mock -CommandName 'Test-Path' -MockWith { return $true }
        New-Directory -Path $path
        Assert-MockCalled -CommandName 'Test-Path'
        Assert-MockCalled -CommandName 'New-Item' -Times 0
    }

    It 'Should create a directory if it does not exist' {
        Mock -CommandName 'Test-Path' -MockWith { return $false }
        New-Directory -Path $path
        Assert-MockCalled -CommandName 'Test-Path'
        Assert-MockCalled -CommandName 'New-Item' -Times 1
    }
}
