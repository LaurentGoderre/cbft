//  Copyright 2020-Present Couchbase, Inc.
//
// Use of this software is governed by the Business Source License included
// in the file licenses/BSL-Couchbase.txt.  As of the Change Date specified
// in that file, in accordance with the Business Source License, use of this
// software will be governed by the Apache License, Version 2.0, included in
// the file licenses/APL2.txt.

package http

import (
	"fmt"
	"net/http"
)

type ListFieldsHandler struct {
	defaultIndexName string
	IndexNameLookup  varLookupFunc
}

func NewListFieldsHandler(defaultIndexName string) *ListFieldsHandler {
	return &ListFieldsHandler{
		defaultIndexName: defaultIndexName,
	}
}

func (h *ListFieldsHandler) ServeHTTP(w http.ResponseWriter, req *http.Request) {

	// find the index to operate on
	var indexName string
	if h.IndexNameLookup != nil {
		indexName = h.IndexNameLookup(req)
	}
	if indexName == "" {
		indexName = h.defaultIndexName
	}
	index := IndexByName(indexName)
	if index == nil {
		showError(w, req, fmt.Sprintf("no such index '%s'", indexName), 404)
		return
	}

	fields, err := index.Fields()
	if err != nil {
		showError(w, req, fmt.Sprintf("error: %v", err), 500)
		return
	}

	fieldsResponse := struct {
		Fields []string `json:"fields"`
	}{
		Fields: fields,
	}

	// encode the response
	mustEncode(w, fieldsResponse)
}
