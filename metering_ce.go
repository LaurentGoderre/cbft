//  Copyright 2022-Present Couchbase, Inc.
//
//  Use of this software is governed by the Business Source License included
//  in the file licenses/BSL-Couchbase.txt.  As of the Change Date specified
//  in that file, in accordance with the Business Source License, use of this
//  software will be governed by the Apache License, Version 2.0, included in
//  the file licenses/APL2.txt.

//go:build !enterprise
// +build !enterprise

package cbft

import (
	"net/http"
	"time"

	"github.com/blevesearch/bleve/v2"
	"github.com/couchbase/cbgt"
	"github.com/couchbase/regulator"
)

func MeteringEndpointHandler(mgr *cbgt.Manager) (string,
	regulator.StatsHttpHandler) {
	return "", nil
}

func MeterWrites(bucket string, index bleve.Index) {
	return
}

func MeterReads(bucket string, index bleve.Index) {
	return
}

func CheckQuotaWrite(bucket, user string,
	req interface{}) (CheckResult, time.Duration, error) {
	return CheckResultNormal, 0, nil
}

func CheckQuotaRead(bucket, user string,
	req interface{}) (CheckResult, time.Duration, error) {
	return CheckResultNormal, 0, nil
}

func WriteRegulatorMetrics(w http.ResponseWriter) {
	return
}
