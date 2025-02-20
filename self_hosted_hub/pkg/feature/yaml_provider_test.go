package feature

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func Test__YAMLProvider(t *testing.T) {

	t.Run("fetches feature configuration from yaml file", func(t *testing.T) {
		provider, err := NewYamlProvider("./test_features.yml")
		assert.Nil(t, err)

		orgID := "org1"
		features, err := provider.ListFeatures(orgID)

		assert.Nil(t, err)
		assert.ElementsMatch(t, []OrganizationFeature{
			{Name: "self_hosted_agents", State: Enabled, Quantity: 500},
		}, features)
	})

}
