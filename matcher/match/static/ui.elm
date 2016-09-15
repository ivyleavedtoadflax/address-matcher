module Ui exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.App as App
import Task exposing (perform)
import Http exposing (..)
import Json.Decode exposing (Decoder, (:=))
import List exposing (..)


main =
    App.program
        { init = init
        , view = view
        , update = update
        , subscriptions = always Sub.none
        }



-- MODEL


type alias User =
    { name : String
    , url : String
    }


type alias TestAddress =
    { address : String
    }


type alias CandidateAddress =
    { address : String
    , uprn : String
    }


type alias Address =
    { test : TestAddress
    , candidates : List CandidateAddress
    }


type alias Model =
    { error : Maybe Error
    , currentUserUri : String
    , users : List User
    , addresses : List Address
    }


init : ( Model, Cmd Msg )
init =
    (Model Nothing "" [] []) ! [ fetchUsers, fetchAddresses ]



-- HTTP


jsonGet : String -> Request
jsonGet url =
    { verb = "GET"
    , headers = [ ( "Accept", "application/json" ) ]
    , url = url
    , body = empty
    }


fetchUsers : Cmd Msg
fetchUsers =
    Task.perform
        FetchUsersFail
        FetchUsersOk
        (fromJson usersDecoder (send defaultSettings (jsonGet "/match/users")))


usersDecoder : Decoder (List User)
usersDecoder =
    (Json.Decode.list
        (Json.Decode.object2 User
            ("name" := Json.Decode.string)
            ("url" := Json.Decode.string)
        )
    )


testAddressDecoder : Decoder (List TestAddress)
testAddressDecoder =
    (Json.Decode.list
        (Json.Decode.object1 TestAddress
            ("address" := Json.Decode.string)
        )
    )


fetchCandidates: TestAddress -> Task.Task Error Address
fetchCandidates testAddress =
    Task.succeed (Address testAddress [])


fetchAddresses : Cmd Msg
fetchAddresses =
    let
        fetchTests : Task.Task Error (List TestAddress)
        fetchTests =
            (fromJson testAddressDecoder
                (send defaultSettings (jsonGet "/match/test-addresses/?n=5"))
            )

        fetchAllCandidates : List TestAddress -> Task.Task Error (List Address)
        fetchAllCandidates testAddresses =
            Task.sequence (List.map fetchCandidates testAddresses)
    in
        Task.perform
            FetchAddressesFail
            FetchAddressesOk
            (fetchTests `Task.andThen` fetchAllCandidates)



-- UPDATE


type Msg
    = FetchUsers
    | FetchUsersOk (List User)
    | FetchUsersFail Http.Error
    | UserChange String
    | FetchAddresses
    | FetchAddressesOk (List Address)
    | FetchAddressesFail Http.Error


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        FetchUsers ->
            ( model, fetchUsers )

        FetchUsersOk users ->
            ( { model | users = users }, Cmd.none )

        FetchUsersFail error ->
            ( { model | error = Just error }, Cmd.none )

        UserChange userUri ->
            ( { model | currentUserUri = userUri }, Cmd.none )

        FetchAddresses ->
            ( model, fetchAddresses )

        FetchAddressesOk addresses ->
            ( { model | addresses = addresses }, Cmd.none )

        FetchAddressesFail error ->
            ( { model | error = Just error }, Cmd.none )



-- VIEW


testAddress : TestAddress -> Html Msg
testAddress address =
    li [] [ address.address |> text ]


-- testAddresses : TestAddresses -> Html Msg
-- testAddresses addresses =
--     ul [] (map testAddress addresses)


userOption : User -> Html Msg
userOption user =
    option [ value user.url ] [ text user.name ]


usersDropdown : List User -> Html Msg
usersDropdown users =
    select [ onInput UserChange ]
        ((option [] [ text "Select a user" ]) :: (map userOption users))


error : Maybe Error -> Html Msg
error message =
    div [] [ text (toString message) ]


view : Model -> Html Msg
view model =
    div []
        [ error model.error
        , usersDropdown model.users
        -- , testAddresses model.testAddresses
          -- , div [] [ text (toString model) ]
        ]
