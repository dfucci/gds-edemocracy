defmodule ExVote.Participations do
  import Ecto.Query

  alias ExVote.Repo
  alias ExVote.Participations.{
    Participation,
    UserParticipation,
    CandidateParticipation,
    ParticipationTicket
  }
  alias ExVote.Projects.Project

  def get_participations(%Project{:id => project_id}, role_filter \\ nil) do
    query = from p in Participation,
      where: p.project_id == ^project_id,
      left_join: u in assoc(p, :user),
      preload: [user: u]

    query = if role_filter do
      from p in query,
        where: p.role == ^role_filter
    else
      query
    end

    Repo.all(query)
    |> Enum.map(&cast_participation/1)
  end

  def get_participation(%{:id => project_id}, %{:id => user_id}, role_filter \\ nil) do
    query = from p in Participation,
      where: p.project_id == ^project_id and p.user_id == ^user_id

    query = if role_filter do
      from p in query,
        where: p.role == ^role_filter
    else
      query
    end

    case Repo.one(query) do
      %Participation{} = participation -> cast_participation(participation)
      nil -> nil
    end
  end

  def cast_participation(%{:role => "user"} = participation) do
    %UserParticipation{}
    |> UserParticipation.changeset_cast(Map.from_struct(participation))
    |> Ecto.Changeset.apply_changes()
  end

  def cast_participation(%Participation{:role => "candidate"} = participation) do
    %CandidateParticipation{}
    |> CandidateParticipation.changeset_cast(Map.from_struct(participation))
    |> Ecto.Changeset.apply_changes()
  end

  def create_participation(attrs) do
    %Participation{}
    |> Participation.changeset_create(attrs)
    |> Ecto.Changeset.apply_changes()
    |> Map.from_struct()
    |> create_typed_participation()
  end

  def create_typed_participation(%{:role => "user"} = attrs) do
    %UserParticipation{}
    |> UserParticipation.changeset_create(attrs)
    |> Repo.insert()
  end

  def create_typed_participation(%{:role => "candidate"} = attrs) do
    %CandidateParticipation{}
    |> CandidateParticipation.changeset_create(attrs)
    |> Repo.insert()
  end

  @deprecated "Use update_votes/2 instead"
  def update_vote(%UserParticipation{} = participation, attrs) do
    participation
    |> UserParticipation.changeset_update_vote(attrs)
    |> Repo.update()
  end

  def update_votes(%UserParticipation{} = participation, attrs) do
    data = %{}
    types = %{votes: {:array, :integer}}

    votes_changeset = {data, types}
    |> Ecto.Changeset.cast(attrs, [:votes])
    |> Ecto.Changeset.validate_required(:votes)
    |> Ecto.Changeset.validate_length(:votes, is: 1, message: "must have exactly one item")

    case Ecto.Changeset.apply_action(votes_changeset, :update) do
      {:ok, %{:votes => [vote]}} ->
        participation
        |> UserParticipation.changeset_update_vote(%{vote_user_id: vote})
        |> Repo.update()
      error ->
        error
    end
  end

  def update_votes(%CandidateParticipation{} = participation, attrs) do

  end

  @deprecated "Use get_votes/1 instead"
  def get_candidate_votes(%CandidateParticipation{:id => participation_id}) do
    query = from pt in ParticipationTicket,
      where: pt.participation_id == ^participation_id,
      left_join: t in assoc(pt, :ticket)

    query
    |> Repo.all()
  end

  def get_votes(%CandidateParticipation{:id => participation_id}) do
    query = from pt in ParticipationTicket,
      where: pt.participation_id == ^participation_id,
      left_join: t in assoc(pt, :ticket),
      preload: [ticket: t]

    query
    |> Repo.all()
    |> Enum.map(fn %{:ticket => ticket} -> ticket end)
  end

  def get_votes(%UserParticipation{} = participation) do
    participation
    |> Repo.preload(:vote_user)
    |> Map.get(:vote_user)
    |> List.wrap()
  end

  def add_candidate_vote(attrs \\ %{}) do
    %ParticipationTicket{}
    |> ParticipationTicket.changeset_create(attrs)
    |> Repo.insert()
  end

  def update_participation(participation, attrs \\ %{})

  def update_participation(
    %{:role => participation_role} = participation,
    %{"role" => role} = attrs
  ) when participation_role != role do
    converted_participation =
      case participation do
        %UserParticipation{} ->
          struct(CandidateParticipation, Map.from_struct(participation))
        %CandidateParticipation{} ->
          struct(UserParticipation, Map.from_struct(participation))
      end

    do_update(converted_participation, attrs)
  end

  def update_participation(participation, attrs), do: do_update(participation, attrs)

  defp do_update(%UserParticipation{} = participation, attrs) do
    participation
    |> UserParticipation.changeset_update(attrs)
    |> Repo.update()
  end

  defp do_update(%CandidateParticipation{} = participation, attrs) do
    participation
    |> CandidateParticipation.changeset_update(attrs)
    |> Repo.update()
  end

  def delete_candidate_vote(id) do
    Repo.delete(%ParticipationTicket{id: id})
  end


end
